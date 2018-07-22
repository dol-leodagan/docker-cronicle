#!/bin/sh

current_container_id="$(basename -- "$(head /proc/1/cgroup)")"

docker_command() {
    host="$1"
    shift 1
    docker_host="$(jq -r -n "$BACKUP_CONFIG"' | ."'"$host"'" | if (.host // "") != "" then .host else empty end')"
    docker_tls="$(jq -r -n "$BACKUP_CONFIG"' | ."'"$host"'" | if .tls == true then "--tls" else empty end')"
    docker_tlsverify="$(jq -r -n "$BACKUP_CONFIG"' | ."'"$host"'" | if .tlsverify == true then "--tlsverify" else empty end')"
    docker_tlscert="$(jq -r -n "$BACKUP_CONFIG"' | ."'"$host"'" | if (.tlscert // "") != "" then .tlscert else "/dev/null" end')"
    docker_tlscacert="$(jq -r -n "$BACKUP_CONFIG"' | ."'"$host"'" | if (.tlscacert // "") != "" then .tlscacert else "/dev/null" end')"
    docker_tlskey="$(jq -r -n "$BACKUP_CONFIG"' | ."'"$host"'" | if (.tlskey // "") != "" then .tlskey else "/dev/null" end')"

    if [ -z "$docker_host" ]; then
        echo "Docker host is empty, it can default to local socket, aborting... (please use $DEFAULT_DOCKER_SOCKET to target local socket)" 1>&2;
        return 7
    fi

    docker \
        --host "$docker_host" \
        $docker_tls \
        $docker_tlsverify \
        --tlscert "$docker_tlscert" \
        --tlscacert "$docker_tlscacert" \
        --tlskey "$docker_tlskey" \
    "$@"
}

default_socket() {
    if [ -S "/var/run/docker.sock" ]; then
        jq -n -r '{ "localhost": { "host": "'"$DEFAULT_DOCKER_SOCKET"'", "tls": false, "tlscacert": "", "tlscert": "", "tlskey": "", "tlsverify": false } }'
    else
        echo '{}'
    fi
}

test_config() {
    hosts="$1"
    if ! jq -e -r -n "$BACKUP_CONFIG" > /dev/null; then
        echo "Config is not valid json !" 1>&2
        return 1
    elif ! jq -e -r -n "$BACKUP_CONFIG"' | map(has("host") and (."host" != "")) | all' > /dev/null; then
        echo "Some entries in Config doesn't have a valid host !" 1>&2
        return 1
    elif [ -n "$hosts" ]; then
        error=0
        IFS=','
        for uniquehost in $hosts; do
            if ! jq -e -r -n "$BACKUP_CONFIG"' | has("'"$uniquehost"'")' > /dev/null; then
                echo "Your host list contains invalid host: $uniquehost" 1>&2
                error=1
            fi
        done
        unset IFS
       [ $error -ne 0 ] && return 1
    fi
    return 0
}

list_host() {
    host="$1"
    volume="$2"
    verbose="$3"

    if [ $verbose -eq 1 ]; then
        jq -r -n "$BACKUP_CONFIG"
    else
        jq -r -n "$BACKUP_CONFIG"' | to_entries | map(
            .key + " : " + (.value.host?|tostring) + 
            "(tls: " + (.value.tls?|tostring) + 
            ", tlsverify: " + (.value.tlsverify?|tostring) + 
            ", tlscacert: " + (.value.tlscacert?|tostring) +
            ", tlskey: " + (.value.tlskey?|tostring) +
            ", tlscert: " + (.value.tlscert?|tostring) +
            ")") | join("\n")'
    fi
}

list_volume() {
    host="$1"
    volume="$2"
    verbose="$3"

    IFS=','
    for uniquehost in $host; do
        docker_volumes=$(docker_command "$uniquehost" volume ls --format '{{json .}}')
        if [ $verbose -eq 1 ]; then
            echo "$docker_volumes" | jq -s -r '{ "'"$uniquehost"'": . }'
        else
            echo "Volumes for $uniquehost : "
            echo "$docker_volumes" | jq -r '"  " + .Name '
        fi
   done
   unset IFS
}

__list_container_using_volume() {
    host="$1"
    volume="$2"
    filter_status="$3"
    filter_rw="$4"

    [ -n "$filter_status" ] && filter_status_string='| select('"$filter_status"')'
    [ "$filter_rw" = "true" ] && filter_rw_string='| select(.RW == true)'


    docker_command "$host" container inspect \
        $(docker_command "$host" container ls --no-trunc --filter=volume="${volume}" --format '{{json .}}' | jq -r '.ID') 2>/dev/null \
        | jq -r '.[] 
                 '"$filter_status_string"'
                 | select(.Mounts[]
                    | select(.Name == "'"$volume"'")
                    | select(.Type == "volume")
                    | select(.Driver == "local")
                    '"$filter_rw_string"'
                    )
                 | .Id'
}

__docker_container_command() {
    host="$1"
    containers="$2"
    comm="$3"


    if [ -z "$containers" ]; then
       echo "No container need ${comm}..." 1>&2
       return 0
    fi

    errors=0
    for container in $containers; do
        # don't act on self container that could make a lot of problem
        if [ "$container" = "$current_container_id" ]; then
            echo "Don't ${comm} Self Container ${current_container_id} or this would bring troubles..." 1>&2
            errors=10
        fi
        echo "Execute ${comm} on Container : (${container}) on docker host (${host})..." 1>&2
        if docker_command "$host" "$comm" "$container" > /dev/null; then
            echo "Done !" 1>&2
        else
            echo "Error while executing ${comm}..." 1>&2
            errors=20
        fi
    done

    return $errors
}

__check_if_image_exists() {
    host="$1"
    if ! docker_command "$host" image inspect "git-volume-backup-volume-aclcopy:latest" > /dev/null; then
        printf "FROM alpine\nRUN apk add --no-cache acl coreutils\nWORKDIR /" \
            | docker_command "$host" build --rm -t "git-volume-backup-volume-aclcopy:latest" -
    fi

}

__backup_volume_to_local() {
    host="$1"
    volume="$2"
    workdir="$3"
    if ! __check_if_image_exists "$host"; then
        echo "Could not fetch or build image for Archiving..." 1>&2
        return 10
    fi
    # Archiving Volume Definition
    docker_command "$host" volume inspect "$volume" --format '{{json .}}' | jq -r '.' > "$workdir"/volume.json && \
        # Archive Times
        docker_command "$host" run --rm -v "$volume":/volume:ro git-volume-backup-volume-aclcopy:latest \
            find volume -exec sh -c 'for f in "$@"; do printf "%s\0%s\0%s\0%s\0\0" "$(stat -c %X "$f")" "$(stat -c %Y "$f")" "$(stat -c %Z "$f")" "$f"; done | gzip -c' {} + \
            | gunzip \
            | jq --slurp -r -R 'split("\u0000\u0000") | map(split("\u0000")) | map({ (.[3]): { "atime": .[0]|tonumber|todateiso8601, "mtime": .[1]|tonumber|todateiso8601, "ctime": .[2]|tonumber|todateiso8601 }}) | add' \
            > "$workdir"/volume.time && \
		# Archiving ACLs
        docker_command "$host" run --rm -v "$volume":/volume:ro git-volume-backup-volume-aclcopy:latest sh -c 'getfacl -R volume | gzip -c' \
            | gunzip > "$workdir"/volume.acl && \
		# Cleanup existing files and archive volume
        rm -rf "$workdir"/volume && \
        docker_command "$host" run --rm -v "$volume":/volume:ro git-volume-backup-volume-aclcopy:latest tar cz volume \
            | tar xz -C "$workdir"
}

__restore_volume_to_remote() {
    host="$1"
    volume="$2"
    workdir="$3"
    if ! __check_if_image_exists "$host"; then
        echo "Could not fetch or build image for Archiving..." 1>&2
        return 10
    fi
	
    # Cleanup volume content
    docker_command "$host" run --rm -v "$volume":/volume:rw git-volume-backup-volume-aclcopy:latest sh -c 'rm -rf volume/* volume/..?* volume/.[!.]*' && \
        # Restore archive to volume
		tar cz -C "$workdir" volume \
			| docker_command "$host" run --rm -i -v "$volume":/volume:rw git-volume-backup-volume-aclcopy:latest tar xz && \
        # Restore acl to volume
		gzip -c "$workdir"/volume.acl \
            | docker_command "$host" run --rm -i -v "$volume":/volume:rw git-volume-backup-volume-aclcopy:latest setfacl --restore=- && \
        # Restore atime and mtime
        jq -r 'to_entries | map((.value.atime|fromdateiso8601|tostring) + "\u0000" + (.value.mtime|fromdateiso8601|tostring) + "\u0000" + (.value.ctime|fromdateiso8601|tostring) + "\u0000" + .key) | join("\u0000")' \
            "$workdir"/volume.time \
            | gzip -c \
            | docker_command "$host" run --rm -i -v "$volume":/volume:rw git-volume-backup-volume-aclcopy:latest sh -c 'gunzip | head -c -1 | xargs -0 -n 4 sh -c '"'"'touch -h -m -c -d @"$1" -- "$3" && touch -h -a -c -d @"$2" -- "$3"'"'"
}
