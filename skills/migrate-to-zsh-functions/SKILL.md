---
name: migrate-to-zsh-functions
description: "Migrate shell mutations to the shared zsh-functions API. USE FOR: converting legacy ~/.functions sourcing loops, vendor PATH leaks, unguarded export PATH lines, or inline PATH/fpath logic in managed-machine, local-bin, or agent-bot-identity into guarded BEGIN/END zsh-functions blocks plus API calls. DO NOT USE FOR: authoring new functions (use add-zsh-function), fresh-Mac bootstrap, auditing writers without changing anything."
license: MIT
metadata:
  author: qwts
---

# Migrate to zsh-functions

Use this skill when replacing hand-rolled shell mutation logic with the shared
API. Run `audit-shell-writers` first when you do not already know every writer
of the target file.

## Before you start

1. Open `AGENTS.md` and [api-catalog.md](../add-zsh-function/references/api-catalog.md).
2. Open [marker-contract.md](references/marker-contract.md) (exact marker strings and semantics).
3. Open [writer-matrix.md](references/writer-matrix.md) (who writes which file and where the
   change lands — templates, never live `~/` files).

## Workflow

1. **Locate** victim lines: `export PATH=`, `fpath=`, `$(brew --prefix)` in
   startup files, `~/.functions` sourcing loops, installer-added PATH blocks.
2. **Classify** each hunk: PATH prepend → `path_prepend_unique`; fpath →
   `fpath_add_unique`; startup wiring → `zsh_functions_init` inside the managed
   block; mid-session brew → `brew_refresh_path`.
3. **Land** per `writer-matrix.md`: dotfile templates in
   `managed-machine-config/dotfiles/zsh/`; block writers in
   `managed-machine/lib/install.sh` (marker-scoped `awk`-strip, same pattern as
   the existing `local-bin`/`nvm`/`rustup` blocks); harness registration in
   `agent-bot-identity/shell-path.mjs` via `ensurePathLine` with **identical**
   marker strings so writers recognize each other's blocks.
4. **Preserve**: back up stale profiles to `.<epoch>.bak`; forward
   `brew shellenv` into `.zprofile` and `.cargo/env` into `.zshenv`; respect
   `ZDOTDIR`; collapse blank-line bloat without touching user lines outside
   markers.
5. **Verify**: [check-dupes.zsh](scripts/check-dupes.zsh) (double-source, assert no dupes);
   `time zsh -ic exit` shows no hot-path `brew` fork; repo suites green
   (`bash tests/*.test.sh` from a neutral dir for managed-machine,
   `npm test` for agent-bot-identity).

## Checklist

- [ ] No unguarded `export PATH=` remains in managed blocks
- [ ] Legacy `~/.functions` sourcing loop replaced by `autoload` path
- [ ] Markers byte-identical across writers; whole-file marker match still dedups
- [ ] Stale files backed up, extras forwarded, `ZDOTDIR` honored
- [ ] No secrets; never `git config user.name/user.email`; no `*.manifest` committed
