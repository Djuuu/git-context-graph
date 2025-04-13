#!/usr/bin/env bash

commit() {
    git commit --allow-empty -m "$1"
}

git_sha() {
    git log --all --oneline | grep "$1" | head -n 1 | cut -d ' ' -f 1
}

reset_to() {
    git reset --hard "$(git_sha "$1")"
}


init_repos() {

    rm -rf ./test-remote ./test-repo

    [[ ! -d test-remote ]] && {
        mkdir test-remote && cd test-remote && git init --bare -b main
        cd ..
    }
    [[ ! -d test-repo ]] && {
        mkdir test-repo && cd test-repo && git init -b main
        git remote add origin ../test-remote
        cd ..
    }

    cd test-repo || exit 1

    git switch main
        commit "Initial commit"
        commit "Main Commit 1"
        commit "Main Commit 2"
        commit "Main Commit 3"
        commit "Main Commit 4"
        commit "Main Commit 5"
        git push --force origin main

    git branch -f feature-1
    git switch feature-1
    reset_to "Main Commit 5"
        commit "Feature 1 - Commit 1"
        commit "Feature 1 - Commit 2"
        commit "Feature 1 - Commit 3"
        commit "Feature 1 - Commit 4"
        git push --force origin feature-1
        reset_to "Feature 1 - Commit 3"

    git branch -f feature-1b
    git switch feature-1b
    reset_to "Feature 1 - Commit 4"
        commit "Feature 1b - Commit 1"
        commit "Feature 1b - Commit 2"
        git push --force origin feature-1b

    git switch main
    commit "Main Commit 6"
    git push --force origin main

    git branch -f feature-2
    git switch feature-2
    reset_to "Main Commit 6"
        commit "Feature 2 - Commit 1"
        commit "Feature 2 - Commit 2"
        commit "Feature 2 - Commit 3b"
        git push --force origin feature-2

    git switch main
    reset_to "Main Commit 6"
        commit "Main Commit 7"
        git push --force origin main
    reset_to "Main Commit 6"

    git branch -f feature-3
    git switch feature-3
    reset_to "Main Commit 5"
        commit "Feature 3 - Commit 1"
        commit "Feature 3 - Commit 2"
        git push --force origin feature-3

    git branch -f feature-4
    git switch feature-4
    reset_to "Main Commit 6"

        commit "Feature 4 - Commit 1"
        commit "Feature 4 - Commit 2"
        commit "Feature 4 - Commit 3"
        git push --force origin feature-4

    git switch feature-2
    reset_to "Feature 2 - Commit 2"
        commit "Feature 2 - Commit 3"
        commit "Feature 2 - Commit 4"

    git branch -f feature-5
    git switch feature-5
    reset_to "Main Commit 7"

        commit "Feature 5 - Commit 1"
        commit "Feature 5 - Commit 2"
        commit "Feature 5 - Commit 3"
        git push --force origin feature-5

    git branch -f feature-6
    git switch feature-6
    reset_to "Main Commit 7"

        commit "Feature 6 - Commit 1"
        commit "Feature 6 - Commit 2"
        git push --force origin feature-6

    git switch feature-2

    git branch -D feature-3
    git branch -D feature-4
    git branch -D feature-5
    git branch -D feature-6
    git branch -D feature-1b

    cd ..
}

init_repos > /dev/null 2>&1

cd test-repo || exit 1

echo
echo "##  git log --graph --oneline  ##########################"
echo
git log --graph --oneline
echo
echo "##  git log --graph --oneline --all  ####################"
echo
git log --graph --oneline --all
echo
echo "##  git context-graph  ##################################"
echo
git context-graph
echo

cd ..
[[ -d ./test-remote ]] && rm -rf ./test-remote
[[ -d ./test-repo ]]   && rm -rf ./test-repo
