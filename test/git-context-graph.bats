#!/usr/bin/env bats

load "test_helper/bats-support/load"
load "test_helper/bats-assert/load"


git() {
    command git \
        -c init.defaultBranch=main \
        -c user.email=test@example.com \
        -c user.name=Test \
        "$@"
}

git-context-graph() {
    "${BATS_TEST_DIRNAME}"/../git-context-graph "$@"
}

setup_file() {
    cd "${BATS_TEST_DIRNAME}" || exit

    [[ -d data ]] && rm -rf data
    mkdir data && cd data || exit

    git init --bare -b main   remote1
    git init --bare -b main   remote2
    git init --bare -b custom remote3

    git init repo && cd repo || exit

    git remote add r1 ../remote1
    git remote add r2 ../remote2
    git remote add r3 ../remote3

    git switch -c main
    git commit --allow-empty -m "Main 1"
    git push r1 main
    git push r2 main
    git push r3 main:custom

    git switch -c feature-A
    git commit --allow-empty -m "Feature A - 1"
    git push r1 feature-A
    git push r2 feature-A

    git switch -c feature-B main
    git commit --allow-empty -m "Feature B - 1"
    git push r1 feature-B
    git push r2 feature-B

    git switch -c feature-C main
    git commit --allow-empty -m "Feature C - 1"
    git push r1 feature-C
    git push r3 feature-C

    git switch -c epic/big-feature main
    git commit --allow-empty -m "Epic B - 1"
    git push r1 epic/big-feature
    git push r2 epic/big-feature

    cd ..
    rm -rf repo
}

teardown_file() {
    cd "${BATS_TEST_DIRNAME}" || exit
    rm -rf data
}

setup() {
    cd "${BATS_TEST_DIRNAME}/data" || exit
}

teardown() {
    cd "${BATS_TEST_DIRNAME}/data" || exit
    rm -rf repo*
}


@test "Command fails outside a Git repository" {
    cd /tmp
    run git-context-graph --list
    assert_failure
}

@test "Local and default branches are shown with remotes" {
    git clone ./remote1 repo && cd repo

    git switch -c feature-A origin/feature-A

    run git-context-graph --list
    assert_output "$(cat <<- EOF
		refs/heads/feature-A
		refs/heads/main
		refs/remotes/origin/feature-A
		refs/remotes/origin/main
		EOF
	)"

    run git-context-graph --list --short
    assert_output "$(cat <<- EOF
		feature-A
		main
		origin/feature-A
		origin/main
		EOF
	)"

    run git-context-graph --list --local
    assert_output "$(cat <<- EOF
		refs/heads/feature-A
		refs/heads/main
		EOF
	)"

    run git-context-graph --list --no-default
    assert_output "$(cat <<- EOF
		refs/heads/feature-A
		refs/remotes/origin/feature-A
		EOF
	)"
}

@test "Patially matching branches are properly excluded" {
    git clone ./remote1 repo && cd repo

    # Other branch with name containing 'feature-A'
    git switch -c backup/feature-A origin/feature-A --no-track
    git push -u origin backup/feature-A

    # Other branch with name containing 'main'
    git switch -c old/main origin/main --no-track

    git switch -c feature-A origin/feature-A

    run git-context-graph --list
    refute_line "refs/heads/backup/feature-A"
    refute_line "refs/remotes/origin/backup/feature-A"
    refute_line "refs/heads/old/main"

    run git-context-graph --list --short
    refute_line "backup/feature-A"
    refute_line "origin/backup/feature-A"
    refute_line "old/main"

    run git-context-graph --list --local
    refute_line "refs/heads/backup/feature-A"
    refute_line "refs/heads/old/main"

    run git-context-graph --list --no-default
    refute_line "refs/heads/backup/feature-A"
    refute_line "refs/remotes/origin/backup/feature-A"

    git push origin --delete backup/feature-A
}

@test "Branches to list can be passed as arguments" {
    git clone ./remote1 repo && cd repo

    git switch -c feature-A origin/feature-A
    git switch -c feature-B origin/feature-B

    run git-context-graph --list --no-default >&3
    assert_output "$(cat <<- EOF
		refs/heads/feature-B
		refs/remotes/origin/feature-B
		EOF
	)"

    run git-context-graph feature-A --list --no-default >&3
    assert_output "$(cat <<- EOF
		refs/heads/feature-A
		refs/remotes/origin/feature-A
		EOF
	)"

    run git-context-graph --add feature-A --list --no-default >&3
    assert_output "$(cat <<- EOF
		refs/heads/feature-A
		refs/heads/feature-B
		refs/remotes/origin/feature-A
		refs/remotes/origin/feature-B
		EOF
	)"
}

@test "Default branch is determined from cloned remote HEAD" {
    git clone ./remote3 repo && cd repo
    git switch -c feature-C origin/feature-C

    run git-context-graph --list
    assert_line "refs/heads/custom"
    assert_line "refs/remotes/origin/custom"

    cd ../
    rm -rf repo

    # consider local branch tracking remote default with a different name

    git clone ./remote3 repo -b feature-C && cd repo
    git switch -c local-custom origin/custom
    git switch feature-C

    run git-context-graph --list
    assert_line "refs/heads/local-custom"
    assert_line "refs/remotes/origin/custom"
}

@test "Default branch determination falls back to standard names" {
    # 'main' is a standard default branch
    (
        git init -b main repo1 && cd repo1
        git commit --allow-empty -m "Main 1"
        git switch -c feature
        git commit --allow-empty -m "feature 1"

        run git-context-graph --list
        assert_line "refs/heads/main"
    )

    # 'master' is a standard default branch
    (
        git init -b master repo2 && cd repo2
        git commit --allow-empty -m "Master 1"
        git switch -c feature
        git commit --allow-empty -m "feature 1"

        run git-context-graph --list
        assert_line "refs/heads/master"
    )

    # No standard default branch identified
    (
        git init -b custom repo3 && cd repo3
        git commit --allow-empty -m "Custom 1"
        git switch -c feature
        git commit --allow-empty -m "feature 1"

        run git-context-graph --list
        assert_output "$(cat <<- EOF
			refs/heads/feature
			EOF
	    )"
    )
}

@test "All remotes are considered" {
    git clone ./remote1 repo && cd repo
    git remote add other ../remote2
    git fetch other

    git switch -c feature-A origin/feature-A

    run git-context-graph --list
    assert_output "$(cat <<- EOF
		refs/heads/feature-A
		refs/heads/main
		refs/remotes/origin/feature-A
		refs/remotes/origin/main
		refs/remotes/other/feature-A
		refs/remotes/other/main
		EOF
	)"
}

@test "Tracking branches with different names are considered" {
    git clone ./remote1 repo && cd repo
    git remote add other ../remote2
    git fetch other

    git switch -c feature-A-local origin/feature-A

    run git-context-graph --list --no-default
    assert_output "$(cat <<- EOF
		refs/heads/feature-A-local
		refs/remotes/origin/feature-A
		EOF
	)"
}

@test "Git-log options are passed to git-log" {
    git clone ./remote1 repo && cd repo

    git switch -c feature-A origin/feature-A

    run git-context-graph --all --pretty=oneline --no-color
    assert_output --partial "(origin/epic/big-feature) Epic B - 1"
    assert_output --partial "(HEAD -> feature-A, origin/feature-A) Feature A - 1"
    assert_output --partial "(origin/feature-B) Feature B - 1"
    assert_output --partial "(origin/main, main) Main 1"
}

@test "Persistent additional context branches can be configured" {
    git clone ./remote1 repo && cd repo

    git switch -c feature-A origin/feature-A
    git switch -c feature-B origin/feature-B
    git switch -c feature-C origin/feature-C
    git switch -c epic/big-feature origin/epic/big-feature

    git switch feature-A

    run git-context-graph --config-add unknown-branch
    assert_output "$(cat <<- EOF
		No additional context branches for feature-A.
		EOF
	)"

    run git-context-graph --config-add epic/big-feature
    assert_output "$(cat <<- EOF
		Additional context branches for feature-A:
		  epic/big-feature
		EOF
	)"

    run git-context-graph feature-A --list --short --local --no-default
    assert_output "$(cat <<- EOF
		epic/big-feature
		feature-A
		EOF
	)"

    git switch main

    run git-context-graph feature-A --config-add feature-B feature-C --config-clear epic/big-feature
    assert_output "$(cat <<- EOF
		Additional context branches for feature-A:
		  feature-B
		  feature-C
		EOF
	)"

    run git-context-graph feature-A --list --short --local --no-default
    assert_output "$(cat <<- EOF
		feature-A
		feature-B
		feature-C
		EOF
	)"

    git switch feature-A

    run git-context-graph --config-clear
    assert_output "$(cat <<- EOF
		Cleared additional context branches for feature-A.
		EOF
	)"

    run git-context-graph --list --short --local --no-default
    assert_output "$(cat <<- EOF
		feature-A
		EOF
	)"
}
