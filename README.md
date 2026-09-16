# zsh-functions

Common zsh functions, installed globally via Homebrew (private tap).

## Install

    brew tap qwts/zsh-functions git@github.com:qwts/zsh-functions.git
    brew install zsh-functions

Then add to `~/.zshrc`:

    fpath=("$(brew --prefix)/share/zsh-functions" $fpath)

Autoload everything:

    for f in "$(brew --prefix)"/share/zsh-functions/*(N); autoload -Uz "${f:t}"

## zsh-profile

`zsh-profile` is the shared editor for the `# BEGIN <name>` / `# END <name>`
managed-block convention used by managed-machine, local-bin, and
agent-bot-identity — callable from bash and node alike.

```
zsh-profile ensure-block       --file F --name NAME [--absorb-marker SUBSTR]...
                               # block body on stdin
zsh-profile remove-block       --file F --name NAME
zsh-profile ensure-line        --file F --marker SUBSTR --line LINE
zsh-profile ensure-path-block  --file F --name NAME --dir DIR [--append]
zsh-profile lint               FILE...
zsh-profile compact            FILE...
```

- Existing blocks are rewritten **in place**; new blocks are appended with a
  single blank separator. Repeated runs never grow whitespace.
- `--absorb-marker` deletes loose lines matching SUBSTR outside managed
  blocks — the migration path for legacy unguarded exports.
- `lint` flags unguarded PATH exports, orphan/duplicate markers, and blank rot.
- `compact` collapses blank runs and strips leading/trailing blanks.
- Marker lines are whole-line, column-zero, byte-identical with what
  `managed-machine`/`local-bin` write today — blocks written by either side
  are recognized and owned by the other.

## Functions

| Function | Description |
|----------|-------------|
| `mkcd <dir>` | Create a directory (with parents) and `cd` into it |

## Adding a function

1. Create `functions/<name>` — filename is the function name.
2. Syntax check: `zsh -n functions/<name>`
3. Commit, tag a `v*` release, `brew reinstall zsh-functions`.

## Uninstall

    brew uninstall zsh-functions
    brew untap qwts/zsh-functions
