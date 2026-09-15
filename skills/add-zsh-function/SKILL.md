---
name: add-zsh-function
description: "Author a new zsh function in qwts/zsh-functions. USE FOR: creating functions/<name>, porting a shell snippet or alias into an autoloadable function, updating Formula/zsh-functions.rb, cutting a v* tag release. DO NOT USE FOR: editing zsh dotfiles (.zshenv/.zprofile/.zshrc), migrating existing PATH/fpath logic to the shared API, auditing who writes shell startup files."
license: MIT
metadata:
  author: qwts
---

# Add a zsh function

Use this skill when creating or porting a function into this repo. Conventions
live in `AGENTS.md` — follow them, they are not repeated here.

## Before you start

1. Open `AGENTS.md` (layout, conventions, verification, private-tap notes).
2. Open [api-catalog.md](references/api-catalog.md) for the canonical helpers. Reuse them —
   do not reimplement PATH/fpath dedup, prefix caching, or init guards inline.
3. Confirm the function name: filename == function name, no extension.

## Workflow

1. **Draft** from [function-template.md](references/function-template.md). Keep it pure zsh (no bash
   compat), `emulate -L zsh` when changing options, `local` vars, `_`-prefixed
   private helpers.
2. **Forbid list** — the new function must not:
   - `export PATH=...` or mutate `fpath` inline (call the catalog helpers);
   - fork `$(brew --prefix)` on its hot path (accept a cached dir variable);
   - `source`/`.` another function file (rely on `autoload`);
   - assume `~/.zshrc` state (must pass the clean-shell smoke test below).
3. **Verify** (from `AGENTS.md`):
   - `zsh -n functions/<name>`
   - `zsh -fc 'fpath+=("$PWD/functions"); autoload -Uz <name>; <name> …'`
   - After formula edits: `brew audit --strict Formula/zsh-functions.rb`
4. **Release**: commit, tag `v*`, `brew reinstall zsh-functions`.

## Checklist

- [ ] One file `functions/<name>` matching its `name() {...}` definition
- [ ] No hot-path `brew` fork, no inline PATH/fpath mutation
- [ ] `zsh -n` and clean-shell smoke test pass
- [ ] `README.md` function table gains a row
- [ ] No secrets; never `git config user.name/user.email`
