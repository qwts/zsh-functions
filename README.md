# zsh-functions

Common zsh functions, installed globally via Homebrew (private tap).

## Install

    brew tap qwts/zsh-functions git@github.com:qwts/zsh-functions.git
    brew install zsh-functions

Then add to `~/.zshrc`:

    fpath=("$(brew --prefix)/share/zsh-functions" $fpath)

Autoload everything:

    for f in "$(brew --prefix)"/share/zsh-functions/*(N); autoload -Uz "${f:t}"

## Functions

| Function | Description |
|----------|-------------|
| _(none yet)_ | |

## Adding a function

1. Create `functions/<name>` — filename is the function name.
2. Syntax check: `zsh -n functions/<name>`
3. Commit, tag a `v*` release, `brew reinstall zsh-functions`.

## Uninstall

    brew uninstall zsh-functions
    brew untap qwts/zsh-functions
