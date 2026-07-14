#!/usr/bin/env bats

load "test_helper/bats-support/load"
load "test_helper/bats-assert/load"

# Isolate the whole test run from current user's git config.
export GIT_CONFIG_GLOBAL="${BATS_TEST_DIRNAME}/.gitconfig"
export GIT_CONFIG_SYSTEM=/dev/null

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

@test "Partially matching branches are properly excluded" {
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

@test "Stale tracking to a deleted remote branch is ignored" {
    git clone ./remote1 repo && cd repo

    git switch -c feature-B origin/feature-B

    # Simulate a remote branch deleted upstream: drop the local remote-tracking
    # ref (as `fetch --prune` would) while branch.feature-B.merge config remains.
    # (Deleting on the shared bare remote would corrupt other tests' fixtures.)
    git update-ref -d refs/remotes/origin/feature-B
    run git config --get branch.feature-B.merge
    assert_output "refs/heads/feature-B"

    # The now-missing remote-tracking ref must not be listed...
    run git-context-graph --list --no-default
    assert_output "refs/heads/feature-B"

    # ...nor passed to git-log, which would fail on the unknown revision
    run git-context-graph --no-default feature-B
    assert_success
}

@test "split_remote_ref splits remote refs and leaves local names untouched" {
    git clone ./remote1 repo && cd repo
    git switch -c feature-A origin/feature-A

    # The script runs its main body when sourced, so load just the helper in isolation
    eval "$(sed -n '/^split_remote_ref()/,/^}/p' "${BATS_TEST_DIRNAME}"/../git-context-graph)"

    assert_equal "$(split_remote_ref origin/feature-A)"              "$(printf 'origin\tfeature-A')"
    assert_equal "$(split_remote_ref refs/remotes/origin/feature-A)" "$(printf 'origin\tfeature-A')"
    assert_equal "$(split_remote_ref origin/epic/big-feature)"       "$(printf 'origin\tepic/big-feature')"
    assert_equal "$(split_remote_ref main)"                          "$(printf '\tmain')"
    assert_equal "$(split_remote_ref refs/heads/main)"               "$(printf '\tmain')"

    # A local branch literally named like a remote ref stays local (not split)
    git switch -c origin/weird origin/feature-A --no-track
    assert_equal "$(split_remote_ref origin/weird)" "$(printf '\torigin/weird')"
}

@test "Remote branch argument focuses that remote" {
    git clone ./remote1 repo && cd repo
    git remote add other ../remote2
    git fetch other

    git switch -c feature-A origin/feature-A
    git switch main

    # Focus origin: local branch + default, on the focused remote only
    run git-context-graph origin/feature-A --list
    assert_output "$(cat <<- EOF
		refs/heads/feature-A
		refs/heads/main
		refs/remotes/origin/feature-A
		refs/remotes/origin/main
		EOF
    )"

    # Full-ref form is equivalent
    run git-context-graph refs/remotes/origin/feature-A --list
    assert_output "$(cat <<- EOF
		refs/heads/feature-A
		refs/heads/main
		refs/remotes/origin/feature-A
		refs/remotes/origin/main
		EOF
    )"
}

@test "Remote branch argument without a local counterpart shows only the remote" {
    git clone ./remote1 repo && cd repo
    git remote add other ../remote2
    git fetch other

    # Only 'main' is checked out locally; feature-B exists on both remotes
    run git-context-graph origin/feature-B --list --no-default
    assert_output "$(cat <<- EOF
		refs/remotes/origin/feature-B
		EOF
    )"
}

@test "Local branch named like a remote ref is treated as local, not focused" {
    git clone ./remote1 repo && cd repo

    git switch -c origin/weird origin/feature-A --no-track

    run git-context-graph origin/weird --list --local --no-default
    assert_output "$(cat <<- EOF
		refs/heads/origin/weird
		EOF
    )"
}

@test "Remote focus also scopes configured context branches" {
    git clone ./remote1 repo && cd repo
    git remote add other ../remote2
    git fetch other

    git switch -c feature-A origin/feature-A
    git switch -c feature-B origin/feature-B
    git switch feature-A

    # feature-A carries feature-B as context (stored as a short local name)
    run git-context-graph --config-add feature-B

    run git-context-graph origin/feature-A --list --no-default
    assert_output "$(cat <<- EOF
		refs/heads/feature-A
		refs/heads/feature-B
		refs/remotes/origin/feature-A
		refs/remotes/origin/feature-B
		EOF
    )"
    refute_line "refs/remotes/other/feature-A"
    refute_line "refs/remotes/other/feature-B"
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

@test "Additional context branches can be toggled" {
    git clone ./remote1 repo && cd repo

    git switch -c feature-A origin/feature-A
    git switch -c feature-B origin/feature-B
    git switch -c feature-C origin/feature-C

    git switch feature-A

    # Not configured yet -> added
    run git-context-graph --config-toggle feature-B
    assert_output "$(cat <<- EOF
		Additional context branches for feature-A:
		  feature-B
		EOF
    )"

    # Already configured -> removed
    run git-context-graph --config-toggle feature-B
    assert_output "$(cat <<- EOF
		No additional context branches for feature-A.
		EOF
    )"

    # Mixed batch: feature-B re-added, feature-C added
    run git-context-graph --config-toggle feature-B
    run git-context-graph --config-toggle feature-B feature-C
    assert_output "$(cat <<- EOF
		Additional context branches for feature-A:
		  feature-C
		EOF
    )"

    run git-context-graph --list --short --local --no-default
    assert_output "$(cat <<- EOF
		feature-A
		feature-C
		EOF
    )"
}

@test "Context branch names are matched exactly, not as regex substrings" {
    git clone ./remote1 repo && cd repo

    git switch -c feature-A origin/feature-A
    # Branches whose names are substrings of one another
    git branch feature-1
    git branch feature-10

    # Adding feature-1 must not be masked by an already-configured feature-10
    run git-context-graph feature-A --config-add feature-10
    run git-context-graph feature-A --config-add feature-1
    assert_success
    assert_output "$(cat <<- EOF
		Additional context branches for feature-A:
		  feature-10
		  feature-1
		EOF
    )"

    # Removing feature-1 must remove only feature-1, not fail on / drop feature-10
    run git-context-graph feature-A --config-clear feature-1
    assert_success
    assert_output "$(cat <<- EOF
		Additional context branches for feature-A:
		  feature-10
		EOF
    )"
}

@test "Context can be synchronized across a set of branches" {
    git clone ./remote1 repo && cd repo

    git switch -c feature-A origin/feature-A
    git switch -c feature-B origin/feature-B
    git switch -c feature-C origin/feature-C
    git switch -c feature-D origin/epic/big-feature

    git switch feature-A
    run git-context-graph --config-add feature-B feature-C

    # Before sync: only feature-A references feature-B and feature-C
    run git-context-graph feature-B --list-status
    assert_output "$(cat <<- EOF
		[ ]	feature-A
		 * 	feature-B
		[ ]	feature-C
		[ ]	feature-D
		EOF
    )"

    # Sync makes the whole set (feature-A, feature-B, feature-C) reference each other
    run git-context-graph --sync
    assert_success
    assert_output "$(cat <<- EOF
		Synchronized context for branches:
		  feature-A
		  feature-B
		  feature-C
		EOF
    )"

    run git-context-graph feature-A --list-status
    assert_output "$(cat <<- EOF
		 * 	feature-A
		[*]	feature-B
		[*]	feature-C
		[ ]	feature-D
		EOF
    )"

    run git-context-graph feature-B --list-status
    assert_output "$(cat <<- EOF
		[*]	feature-A
		 * 	feature-B
		[*]	feature-C
		[ ]	feature-D
		EOF
    )"

    run git-context-graph feature-C --list-status
    assert_output "$(cat <<- EOF
		[*]	feature-A
		[*]	feature-B
		 * 	feature-C
		[ ]	feature-D
		EOF
    )"

    # Sync replaces existing context (feature-D not part of the set is untouched,
    # but a branch's own pre-existing context outside the set is dropped)
    git switch feature-B
    run git-context-graph --config-add feature-D
    run git-context-graph feature-A --sync
    run git-context-graph feature-B --list --short --local --no-default
    assert_output "$(cat <<- EOF
		feature-A
		feature-B
		feature-C
		EOF
    )"

    # Nothing to synchronize with a lone branch
    run git-context-graph feature-D --sync
    assert_failure
    assert_output --partial "Nothing to synchronize"
}

@test "Context edits are propagated to the whole preset with --sync" {
    git clone ./remote1 repo && cd repo

    git switch -c feature-A origin/feature-A
    git switch -c feature-B origin/feature-B
    git switch -c feature-C origin/feature-C

    git switch feature-A

    # Seed a two-branch preset (feature-A <-> feature-B) in a single call
    run git-context-graph --config-add feature-B --sync
    assert_success
    assert_output "$(cat <<- EOF
		Synchronized context for branches:
		  feature-A
		  feature-B
		EOF
    )"

    # Adding feature-C with --sync mirrors it across the whole set
    run git-context-graph --config-add feature-C --sync
    assert_success
    assert_output "$(cat <<- EOF
		Synchronized context for branches:
		  feature-A
		  feature-B
		  feature-C
		EOF
    )"

    # Every branch now references the other two
    run git-context-graph feature-B --list-status
    assert_output "$(cat <<- EOF
		[*]	feature-A
		 * 	feature-B
		[*]	feature-C
		EOF
    )"

    run git-context-graph feature-C --list-status
    assert_output "$(cat <<- EOF
		[*]	feature-A
		[*]	feature-B
		 * 	feature-C
		EOF
    )"
}

@test "Removing from a preset with --sync detaches the branch, preserving unrelated context" {
    git clone ./remote1 repo && cd repo

    git switch -c feature-A origin/feature-A
    git switch -c feature-B origin/feature-B
    git switch -c feature-C origin/feature-C
    git switch -c feature-D origin/epic/big-feature

    git switch feature-A

    # Build a three-branch preset
    run git-context-graph --config-add feature-B feature-C --sync

    # feature-C also carries an unrelated context branch (feature-D)
    run git-context-graph feature-C --config-add feature-D

    # Toggle feature-C out of feature-A's context, then sync
    run git-context-graph --config-toggle feature-C --sync
    assert_success
    assert_output "$(cat <<- EOF
		Synchronized context for branches:
		  feature-A
		  feature-B
		Detached from preset:
		  feature-C
		EOF
    )"

    # feature-A and feature-B reference each other, no longer feature-C
    run git-context-graph feature-A --list-status
    assert_output "$(cat <<- EOF
		 * 	feature-A
		[*]	feature-B
		[ ]	feature-C
		[ ]	feature-D
		EOF
    )"

    # feature-C dropped the preset members but kept its unrelated context (feature-D)
    run git-context-graph feature-C --list --short --local --no-default
    assert_output "$(cat <<- EOF
		feature-C
		feature-D
		EOF
    )"
}

@test "Clearing a branch's context with --sync empties the whole preset" {
    git clone ./remote1 repo && cd repo

    git switch -c feature-A origin/feature-A
    git switch -c feature-B origin/feature-B
    git switch -c feature-C origin/feature-C
    git switch -c feature-D origin/epic/big-feature

    git switch feature-A
    run git-context-graph --config-add feature-B feature-C --sync

    # feature-B also carries an unrelated context branch (feature-D)
    run git-context-graph feature-B --config-add feature-D

    # Clearing the source's whole context + --sync tears the preset down:
    # every member drops the others, keeping only unrelated context
    run git-context-graph --config-clear --sync
    assert_success
    assert_output "$(cat <<- EOF
		Context preset for feature-A is now empty.
		Detached from preset:
		  feature-B
		  feature-C
		EOF
    )"

    run git-context-graph feature-A --list --short --local --no-default
    assert_output "feature-A"

    # feature-B and feature-C no longer reference each other or feature-A
    run git-context-graph feature-C --list-status
    assert_output "$(cat <<- EOF
		[ ]	feature-A
		[ ]	feature-B
		 * 	feature-C
		[ ]	feature-D
		EOF
    )"

    # feature-B kept only its unrelated context (feature-D)
    run git-context-graph feature-B --list --short --local --no-default
    assert_output "$(cat <<- EOF
		feature-B
		feature-D
		EOF
    )"
}

@test "--sync rejects more than one source branch" {
    git clone ./remote1 repo && cd repo

    git switch -c feature-A origin/feature-A
    git switch -c feature-B origin/feature-B
    git switch -c feature-C origin/feature-C

    run git-context-graph feature-B feature-C --config-add feature-A --sync
    assert_failure
    assert_output --partial "single branch"
}

@test "--sync used on its own synchronizes a branch's existing context" {
    git clone ./remote1 repo && cd repo

    git switch -c feature-B origin/feature-B
    git switch -c feature-C origin/feature-C

    # feature-B references feature-C; a bare --sync mirrors the whole set
    git switch feature-B
    run git-context-graph --config-add feature-C
    run git-context-graph --sync
    assert_success
    assert_output "$(cat <<- EOF
		Synchronized context for branches:
		  feature-B
		  feature-C
		EOF
    )"

    # feature-C now references feature-B in return
    run git-context-graph feature-C --list --short --local --no-default
    assert_output "$(cat <<- EOF
		feature-B
		feature-C
		EOF
    )"
}

@test "Available local branches are listed with context status" {
    git clone ./remote1 repo && cd repo

    git switch -c feature-A origin/feature-A
    git switch -c feature-B origin/feature-B
    git switch -c feature-C origin/feature-C

    git switch feature-A
    run git-context-graph --config-add feature-B

    run git-context-graph --list-status
    assert_success
    assert_output "$(cat <<- EOF
		 * 	feature-A
		[*]	feature-B
		[ ]	feature-C
		EOF
    )"
    refute_output --partial "main"

    git switch feature-B
    run git-context-graph --config-add feature-C
    run git-context-graph --list-status
    assert_success
    assert_output "$(cat <<- EOF
		[ ]	feature-A
		 * 	feature-B
		[*]	feature-C
		EOF
    )"

    run git-context-graph feature-A --list-status
    assert_success
    assert_output "$(cat <<- EOF
		 * 	feature-A
		[*]	feature-B
		[ ]	feature-C
		EOF
    )"

    # On the default branch: all branches listed, none flagged as current
    git switch main
    run git-context-graph --list-status
    assert_success
    assert_output "$(cat <<- EOF
		[ ]	feature-A
		[ ]	feature-B
		[ ]	feature-C
		EOF
    )"
    refute_output --partial "main"

    # On a detached HEAD: all branches listed, none flagged as current
    git switch feature-A
    git switch --detach
    run git-context-graph --list-status
    assert_success
    assert_output "$(cat <<- EOF
		[ ]	feature-A
		[ ]	feature-B
		[ ]	feature-C
		EOF
    )"
    refute_output --partial "main"
}

@test "Whole repository context configuration can be reset" {
    git clone ./remote1 repo && cd repo

    git switch -c feature-A origin/feature-A
    git switch -c feature-B origin/feature-B
    git switch -c feature-C origin/feature-C

    # Configure context on two different branches
    run git-context-graph feature-A --config-add feature-B
    run git-context-graph feature-B --config-add feature-C

    # Persist a fold preference too
    run git-context-graph --fold
    run git config --local --get context-graph.first-parent
    assert_output "true"

    # Declining the confirmation leaves the configuration untouched
    run git-context-graph --config-reset <<< "n"
    assert_success
    assert_output "$(cat <<- EOF
		This will remove the following context-graph configuration:
		  branch context:
		    feature-A
		    feature-B
		  context-graph.first-parent (true)
		Aborted.
		EOF
    )"
    run git config --local --get-all branch.feature-A.context
    assert_output "feature-B"
    run git config --local --get context-graph.first-parent
    assert_output "true"

    # Confirming removes context configuration for every branch
    run git-context-graph --config-reset <<< "y"
    assert_success
    assert_output "$(cat <<- EOF
		This will remove the following context-graph configuration:
		  branch context:
		    feature-A
		    feature-B
		  context-graph.first-parent (true)
		Context-graph configuration removed.
		EOF
    )"

    run git-context-graph feature-A --config-add feature-C
    run git config --local --get-all branch.feature-A.context
    assert_output "feature-C"
    run git config --local --get-all branch.feature-B.context
    assert_output ""
    run git config --local --get context-graph.first-parent
    assert_output ""
}

@test "Resetting with no configuration reports nothing to reset" {
    git clone ./remote1 repo && cd repo

    git switch -c feature-A origin/feature-A

    run git-context-graph --config-reset <<< "y"
    assert_success
    assert_output "No context-graph configuration to reset."
}

@test "--fold / --unfold control first-parent and persist to config" {
    git clone ./remote1 repo && cd repo

    git switch -c feature-A origin/feature-A

    # Merge a side branch so a commit is only reachable via the merge's second parent
    git switch -c side --no-track
    git commit --allow-empty -m "Side commit"
    git switch feature-A
    git merge --no-ff --no-edit -m "Merge side" side

    # No stored preference: default off -> full graph shows the merged-in commit
    run git-context-graph --pretty=oneline --no-color
    assert_output --partial "Side commit"

    # --unfold with a base branch renders the full graph and stores 'false'
    run git-context-graph feature-A --unfold --pretty=oneline --no-color
    assert_output --partial "Side commit"
    run git config --local --get context-graph.first-parent
    assert_output "false"

    # --fold with no base branch is a config-op: stores 'true', no graph output
    run git-context-graph --fold
    assert_success
    assert_output ""
    run git config --local --get context-graph.first-parent
    assert_output "true"

    # Stored 'true' now folds the default graph: merged-in commit hidden, merge kept
    run git-context-graph --pretty=oneline --no-color
    refute_output --partial "Side commit"
    assert_output --partial "Merge side"

    # Explicit --unfold overrides the stored value for the run
    run git-context-graph feature-A --unfold --pretty=oneline --no-color
    assert_output --partial "Side commit"
}

@test "--fold-toggle flips the stored first-parent value" {
    git clone ./remote1 repo && cd repo

    git switch -c feature-A origin/feature-A

    # From unset (effective false) -> toggles on, no graph output (config-op)
    run git-context-graph --fold-toggle
    assert_success
    assert_output ""
    run git config --local --get context-graph.first-parent
    assert_output "true"

    # -> toggles off
    run git-context-graph --fold-toggle
    run git config --local --get context-graph.first-parent
    assert_output "false"

    # -> toggles on again
    run git-context-graph --fold-toggle
    run git config --local --get context-graph.first-parent
    assert_output "true"
}
