# AGENTS.md

## Purpose

Personal collection of common zsh functions, installed globally via Homebrew
from a **private** tap. Everything here is zsh — no bash compatibility needed.

## Layout

- `functions/` — one file per function, filename == function name, no extension
  (autoload convention)
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

## Brew / private-tap notes

- Tap via SSH: `brew tap qwts/zsh-functions git@github.com:qwts/zsh-functions.git`
- Formula uses a `git@` source URL so SSH creds handle auth — no
  `HOMEBREW_GITHUB_API_TOKEN` required.
- Tag releases `v*` for versioned installs.
