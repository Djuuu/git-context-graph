# git-context-graph

Show graph log of branch with its remote counterparts and default repository branch.

This is a shortcut to `git log --graph` which provides a middle ground between
showing _only a given branch_ (which might lack context) and showing _all_ branches 
(which might get crowded on big projects).

|                `git log --graph`                 |               `git log --graph --all`               |
|:------------------------------------------------:|:---------------------------------------------------:|
| ![git log --graph](doc/git-log-graph-single.png) | ![git log --graph --all](doc/git-log-graph-all.png) |

|                **`git context-graph`**                |
|:-----------------------------------------------------:|
| ![git context-graph](doc/git-context-graph-large.png) |

## Synopsis

<code><b>git context-graph</b> <i>[--no-default] [&lt;branch&gt;...]</i></code>  
<code><b>git</b> <b>context-graph</b> <i>[&lt;git-log options&gt;] [--no-default] [&lt;branch&gt;...] [-- &lt;paths&gt;...]</i></code>  

<code><b>git context-graph</b> <i>(--list-context|--list-related|--list-default) [&lt;branch&gt;]</i></code>  

<code><b>git context-graph</b> <i>--usage</i></code>

## Description

This command is a shortcut to:
```bash
git log --color --graph --abbrev-commit --decorate --pretty=oneline \
    <branch> origin/<branch> other-remote/<branch> ... \
    [main    origin/main     other-remote/main] ...
```

* <code><b>git</b> <b>context-graph</b> <i>[--no-default] [&lt;branch&gt;...]</i></code>  
  Show graph log of branch, its remote counterparts and default branch.

* <code><b>git</b> <b>context-graph</b> <i>[&lt;git-log options&gt;] [--no-default] [&lt;branch&gt;...] [-- &lt;paths&gt;...]</i></code>  
  `git-log` options can be used to refine or customize the output  
  (see git-log documentation: https://git-scm.com/docs/git-log)  
  Ex:  
  <code>git context-graph --pretty=medium -- some/path</code>

* <code><b>git</b> <b>context-graph</b> <i>(--list-related|--list-default|--list-context) [&lt;branch&gt;...]</i></code>  
  List branches that would be shown in the graph.

* <code><b>git</b> <b>context-graph</b> <i>--usage</i></code>  
  Show the help page.

## Arguments

* `<branch>...`  
  Branches to show graph for. If omitted, current branch will be used.

## Options

* `--no-default`  
  Show only related branches (local and remote), without default branch.

* `--list-context`  
  List both related and default branches (does not display graph).

* `--list-related`  
  List related branches (local and remote) (does not display graph).

* `--list-default`  
  List repository default branch(es) (does not display graph).

* `--usage`  
  Show command usage.

## Installation

* Add the `git-context-graph` directory to your `PATH`<br>
  in one of your shell startup scripts:
  ```bash
  PATH="${PATH}:/path/to/git-context-graph"
  ```

_OR_ 

* Define it as a git alias:<br>
  run:
  ```bash
  git config --global alias.cg '!bash /path/to/git-context-graph/git-context-graph'
  ```
  or edit your `~/.gitconfig` directly:
  ```
  [alias]
  	cg = "!bash /path/to/git-context-graph/git-context-graph"
  ```
