#!/bin/zsh

set -eu
setopt pipefail

repo_dir="${0:A:h}"
dry_run=0

usage() {
    print -- "Usage: ./update.sh [--dry-run]"
    print -- "  --dry-run  Check the remote and installer without changing the checkout or the Mac."
}

while (( $# )); do
    case "$1" in
        --dry-run)
            dry_run=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            print -u2 -- "Unknown option: $1"
            usage >&2
            exit 2
            ;;
    esac
    shift
done

if [[ ! -d "$repo_dir/.git" ]]; then
    print -u2 -- "This checkout is not a Git repository. Clone it again before updating."
    exit 1
fi

if [[ -n "$(git -C "$repo_dir" status --porcelain)" ]]; then
    print -u2 -- "The checkout contains local changes. Commit or preserve them before updating."
    exit 1
fi

if ! git -C "$repo_dir" symbolic-ref -q HEAD >/dev/null; then
    print -u2 -- "The checkout has a detached HEAD. Switch to a branch before updating."
    exit 1
fi

if ! git -C "$repo_dir" rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1; then
    print -u2 -- "The current branch has no upstream remote."
    exit 1
fi

if (( dry_run )); then
    git -C "$repo_dir" fetch --dry-run origin
    exec "$repo_dir/install.sh" --dry-run
fi

git -C "$repo_dir" pull --ff-only
exec "$repo_dir/install.sh"
