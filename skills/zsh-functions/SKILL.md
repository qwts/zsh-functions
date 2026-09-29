---
name: zsh-functions
description: "Use the installed zsh-functions API and the zsh-profile managed-block editor. USE FOR: adding a directory to PATH or fpath once, wiring zsh_functions_init, writing or removing a guarded BEGIN/END block in a zsh startup file, linting a startup file for duplicate blocks or unguarded PATH exports. DO NOT USE FOR: authoring a new function (use add-zsh-function), migrating another repo's writers (use migrate-to-zsh-functions), finding who writes a file (use audit-shell-writers)."
license: MIT
metadata:
  qwts-contract: "1"
  qwts-cli: "zsh-profile"
  qwts-versions: ">=0.2.0 <0.3.0"
  qwts-validated: "0.2.0"
  qwts-side-effects: "local-write"
---

# zsh-functions

Run `zsh-profile --version` first. If the version is outside `qwts-versions`,
treat this skill as a hint: take each command's behavior from that version's
`zsh-profile --help`, and write nothing it does not vouch for.
`zsh-profile skill-path` prints the installed release's copy of this skill.

## Choose the tool

- Inside zsh, call the API; do not reimplement it. The helpers and their
  contracts are in [api-catalog.md](references/api-catalog.md).
- To change a startup file from a script or another repo's installer, use
  `zsh-profile`. It owns the `# BEGIN <name>` / `# END <name>` contract, so
  every writer recognizes every other writer's blocks. Its options are in
  `zsh-profile --help`.
- Write the `.zshenv` zsh actually reads: `$ZDOTDIR/.zshenv` when `ZDOTDIR` is
  set, otherwise `$HOME/.zshenv`.

## Side effects and retries

| Class | Commands | Retry |
|---|---|---|
| read-only | `--version`, `--help`, `skill-path`, `lint` | Safe to repeat. |
| local-write | `ensure-block`, `ensure-path-block`, `ensure-line`, `remove-block`, `compact` | Safe to repeat: writes are atomic and converge, so a second run reports `unchanged`. |

`ensure-block` reads the block body from stdin; an empty body is an error, not
a removal. `--absorb-marker` deletes matching lines outside managed blocks, so
name only markers your own writer used to own.

## Read the output

- Success prints one line per file on stdout: `ensured …`, `removed …`,
  `compacted …`, or `unchanged …`. Treat `unchanged` as success.
- `lint` prints `file:line: finding` lines and exits 1 when it finds any; a
  clean file prints nothing and exits 0.
- Every error goes to stderr as `zsh-profile: <message>` with exit 1.
