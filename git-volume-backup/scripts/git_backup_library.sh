#!/bin/sh

git_repostitory_uri="${BACKUP_GIT_REPOSITORY_URI:-/git}"

export GIT_COMMITTER_NAME="${GIT_COMMITTER_NAME:-${BACKUP_GIT_COMMITTER_NAME:-${HOSTNAME}}}"
export GIT_COMMITTER_EMAIL="${GIT_COMMITTER_EMAIL:-${BACKUP_GIT_COMMITTER_EMAIL:-$(whoami)@${HOSTNAME}}}"
export GIT_AUTHOR_NAME="$GIT_COMMITTER_NAME"
export GIT_AUTHOR_EMAIL="$GIT_COMMITTER_EMAIL"

cgit() {
    workdir="$1"
    shift
    git --work-tree="$workdir" --git-dir="${workdir}/.git" "$@"
}

list_backup() {
    host="$1"
    volume="$2"
    verbose="$3"
    list_branches=$(git ls-remote --heads "$git_repostitory_uri" \
        | jq -R -r -s 'split("\n")
                        | map(if . != "" then . | split("\t") else empty end)
                        | map( { commit: .[0], host: .[1]|gsub("refs/heads/(?<host>[^/]+)/.+"; .host), volume: .[1]|gsub("refs/heads/[^/]+/(?<vol>.+)"; .vol) } )
                        | group_by(.host) 
                        | map({ (.[0].host): (. | map({ commit: .commit, volume: .volume })) })
                        | add
                        ')
    IFS=','
    for uniquehost in $host; do
        if [ $verbose -eq 1 ]; then
            jq -r -n "$list_branches"' | { "'"$uniquehost"'" : (."'"$uniquehost"'" // []) }'
        else
            jq -r -n "$list_branches"' | "Host: '"$uniquehost"'\n    Backups:\n    " + ((."'"$uniquehost"'" // []) | map(.volume + ": " + .commit) | join("\n    "))'
        fi
    done
    unset IFS

    rm -rf "$workdir"
}

__create_git_temporary_repository() {
    workdir="$1"
    branch="$2"

    # Try Creating Git and adding remote
    if ! cgit "$workdir" init; then return 1; fi

    if cgit "$workdir" remote add origin "$git_repostitory_uri"; then
        # Check if remote branch exists
        if cgit "$workdir" ls-remote --exit-code --heads origin "$branch"; then
            cgit "$workdir" fetch --depth=1 origin "$branch" && \
                cgit "$workdir" checkout "$branch"
        else
            cgit "$workdir" checkout --orphan "$branch"
        fi
    else
        return 2
    fi
}

__create_git_temporary_repository_and_fetch() {
    workdir="$1"
    branch="$2"
    commit="$3"

    # Try Creating Git and adding remote
    if ! cgit "$workdir" init; then return 1; fi

    if cgit "$workdir" remote add origin "$git_repostitory_uri"; then
        # fetch remote commit
        if cgit "$workdir" fetch --depth=1 origin "$commit":"$branch"; then
            cgit "$workdir" checkout "$branch"
        else
            return 3
        fi
    else
        return 2
    fi
}

__add_commit_and_push() {
    workdir="$1"
    branch="$2"
    message="${3:-Backup Pushed by backup script}"

    cgit "$workdir" add . && \
        if ! cgit "$workdir" diff-index --cached --quiet HEAD -- ; then
            cgit "$workdir" commit -m "$message" && \
                cgit "$workdir" push --set-upstream origin "$branch"
        else
            return 100
        fi
}

__rollup_dotgit_dir() {
    workdir="$1"

    rm -rf "$workdir"/*.tar "$workdir"/dotgit && \
        (cd -- "$workdir"/volume && find . -type d -name ".git" -exec sh -c '\
            for f in "$@"; do
                archive_path="$(printf "%s" "$f" | sha256sum | cut -d " " -f1)" && \
                    mkdir -p "'"$workdir"'"/dotgit/ && \
                    echo "$f" > "'"$workdir"'"/dotgit/"$archive_path".git.path && \
                    mv -- "$f" "'"$workdir"'"/dotgit/"$archive_path".git
            done' \
            - {} +)
}

__unroll_dotgit_dir() {
    workdir="$1"
    for path in "$workdir"/dotgit/*.git; do
        [ ! -e "$path" ] && continue
        origin_path="$(cat "$path".path)"
        mv -- "$path" "$workdir"/volume/"$origin_path"
    done
}
