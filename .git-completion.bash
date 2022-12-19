# "lighter" _git_log completion
# See https://github.com/git/git/blob/master/contrib/completion/git-completion.bash
_git_context_graph() {
    __git_has_doubledash && return

    case "$cur" in
        --pretty=* | --format=*)
            __gitcomp "$__git_log_pretty_formats $(__git_pretty_aliases)
			" "" "${cur#*=}"
            return
            ;;
        --date=*)
            __gitcomp "$__git_log_date_formats" "" "${cur##--date=}"
            return
            ;;
        --decorate=*)
            __gitcomp "full short no" "" "${cur##--decorate=}"
            return
            ;;
        --submodule=*)
            __gitcomp "$__git_diff_submodule_formats" "" "${cur##--submodule=}"
            return
            ;;
        --*)
            __gitcomp "
            --add --no-default --list --short --usage
            --all --branches --tags --remotes
            --simplify-merges --simplify-by-decoration
            --abbrev-commit --no-abbrev-commit --abbrev=
            --relative-date --date=
			--pretty= --format= --oneline
			--decorate --decorate= --no-decorate
			"
            return
            ;;
    esac

    __git_complete_revlist
}


# Add completion for aliases
for a in $(alias -p | grep "git[- ]context-graph" | cut -d' ' -f2 | cut -d= -f1); do
    __git_complete "$a" _git_context_graph
done
