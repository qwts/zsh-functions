# AGENTS.md

## Purpose

Personal collection of common zsh functions, installed globally via Homebrew
from a **private** tap. Everything here is zsh — no bash compatibility needed.

## Layout

- `functions/` — one file per function, filename == function name, no extension
  (autoload convention)
- `install` + `lib/install.sh` — machine install (mirrors local-bin): links,
  manifest, managed `.zshenv` loader block via `bin/zsh-profile`
- `Formula/zsh-functions.rb` — Homebrew formula

## Conventions

- Each function file contains a `name() { ... }` definition matching the filename.
- Use zsh idioms freely; quote expansions; declare `local` variables.
- Start functions that change options with `emulate -L zsh`.
- Prefix private helpers with `_`.

## Verification

- Syntax check: `zsh -n functions/<name>`
- Smoke test in a clean shell (catches hidden .zshrc deps):
  `zsh -fc 'fpath+=("$PWD/functions"); autoload -Uz <name>; <name>'`
- After formula edits: `brew audit --strict Formula/zsh-functions.rb`
- `zsh-profile` tests are plain bash, no runner:
  `bash tests/zsh-profile.test.sh` — run from a neutral working directory
- `install` tests are plain bash with an isolated `HOME`, no runner:
  `bash tests/install.test.sh` — same convention, never touches the real `~/`

## zsh-profile / managed-block conventions

- `bin/zsh-profile` is the canonical implementation of the
  `# BEGIN <name>` / `# END <name>` marker contract; callers in
  managed-machine, local-bin, and agent-bot-identity delegate to it when it is
  on PATH and keep internal fallbacks for bootstrap order
- block bodies callers write must be dedup-guarded — `zsh-profile` never edits
  inside markers; edits are atomic (same-dir temp + mv) and preserve the
  file's mode
- honor `ZDOTDIR`: with it set, zsh reads `$ZDOTDIR/.zshenv`, never
  `$HOME/.zshenv`
- never `git config` user.name/user.email

## Brew / private-tap notes

- Tap via SSH: `brew tap qwts/zsh-functions git@github.com:qwts/zsh-functions.git`
- Formula uses a `git@` source URL so SSH creds handle auth — no
  `HOMEBREW_GITHUB_API_TOKEN` required.
- Tag releases `v*` for versioned installs.
