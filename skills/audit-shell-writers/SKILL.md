---
name: audit-shell-writers
description: "Audit zsh startup-file writers before changing shell behavior. USE FOR: mapping who writes .zshenv/.zprofile/.zshrc across repos, finding marker or ZDOTDIR conflicts, tracing PATH/fpath duplication sources, pre-migration recon. DO NOT USE FOR: making the change itself (use migrate-to-zsh-functions), authoring functions (use add-zsh-function), machine bootstrap or update."
license: MIT
metadata:
  author: qwts
---

# Audit shell writers

Read-only recon. This skill never writes dotfiles, never runs `setup`,
`bootstrap`, or `--update`, and never edits live `~/` files. Produce a
conflict table and a migrate/leave verdict per hunk; hand the verdicts to
`migrate-to-zsh-functions`.

## Inventory (in this order)

1. **Templates**: `managed-machine-config/dotfiles/zsh/.zshenv`, `.zprofile`,
   `.zshrc` — what a fresh `setup zsh` installs.
2. **Writers**: `managed-machine-config/config/zsh`,
   `managed-machine/lib/install.sh` (`ensure_*_in_zshrc`,
   `zsh_profile_needs_refresh`, `preserve_zsh_profile_extras`),
   `managed-machine/setup-zsh*`, `local-bin/install` (marker blocks),
   `agent-bot-identity/shell-path.mjs` (`ensurePathLine`, markers) plus
   `install.mjs` / `install-gh-shim.mjs` call sites.
3. **Live state**: `~/.zshrc`, `~/.zshenv`, `~/.zprofile` (honor `ZDOTDIR` —
   with it set, zsh reads `$ZDOTDIR/.zshenv`, never `$HOME/.zshenv`),
   `~/.functions/` contents, `$(brew --prefix)/share/zsh-functions/` presence.
4. **Smells**: unguarded `export PATH=...` (stacks on nested shells), inline
   `$(brew --prefix)` in startup files (forks brew per shell), `source`/`.`
   loops over function dirs (use `autoload`), vendor installer blocks outside
   managed markers, blank-line bloat, duplicated comments.

## Output

A table — file × writer × marker × guarded? — plus one verdict per hunk:

- **migrate**: hand to `migrate-to-zsh-functions` with the target API named;
- **leave**: user-owned or vendor content outside markers — report, do not touch;
- **watch**: installer-owned lines forwarded on refresh (`brew shellenv`,
  `.cargo/env`) — confirm they survive, change nothing.

## Checklist

- [ ] Every `export PATH` / `fpath` / `brew --prefix` hit attributed to a writer
- [ ] `ZDOTDIR` resolved before judging any `.zshenv` finding
- [ ] No file written, no setup command run, no secrets recorded
