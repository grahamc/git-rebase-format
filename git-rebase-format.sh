#!/usr/bin/env bash

# Rebase one branch on top of another, where the target branch
# reformatted everything automatically but made no other changes
# and you just want:
# 1. to rebase cleanly
# 2. have all your commits cleanly formatted
# 3. not fight with any annoying conflicts that are meaningless
#
# usage:
# $ ~/git-rebase-format.sh origin/master shfmt -w .
#

set -eux

scratch=$(mktemp -d -t tmp.XXXXXXXXXX)
function finish {
  rm -rf "$scratch"
}
trap finish EXIT

capture_commits_to_edit() (
    first_commit=$1
    if [ ! -f "$scratch/commits-to-edit" ]; then
        git rev-list "$first_commit..HEAD" | tac > "$scratch/commits-to-edit"
    fi
)

commits_to_edit() (
    cat "$scratch/commits-to-edit"
)

git_add_for_commit() (
    commit="$1"

    # Don't commit any files by default, the cherry-pick
    # might make some bad assumptions about what we're
    # trying to do.
    git restore --staged .

    for f in $(git show --pretty=format: --name-only "$commit"); do
        if [ -e "$f" ]; then
            git add "$f"
        fi
    done
)



main() (
    first_commit=$1
    shift

    capture_commits_to_edit "$first_commit"

    git branch -D "rebase-rfmt" || true
    git checkout -b "rebase-rfmt"
    git reset --hard "$first_commit"

    for commit in $(commits_to_edit); do
        git clean -dfx
        git reset --hard
        if ! git cherry-pick "$commit";  then
            git checkout "$commit" -- ./
            "$@"

            git_add_for_commit "$commit"


            if ! EDITOR=cat git cherry-pick --continue; then
                git commit --allow-empty --no-edit
            fi
        else
            "$@"

            git_add_for_commit "$commit"
            git commit --amend --no-edit
        fi
    done
)

main "$@"
