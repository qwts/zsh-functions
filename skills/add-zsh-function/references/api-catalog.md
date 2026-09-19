# API catalog

Canonical runtime helpers owned by this repo. Call them; do not reimplement
their logic in new functions or in consumer repos.

> Status note: the helpers below are the **Phase-1 interface**, implemented in
> `functions/`. Names and semantics are frozen by this document.

| Helper | Role | Key contract |
|---|---|---|
| `path_prepend_unique <dir>` | Prepend `<dir>` to `PATH` once | No-op (exit 0) when `<dir>` is missing/unreadable, so read-only brew prefixes still work; never duplicates on nested shells |
| `fpath_add_unique <dir>` | Prepend `<dir>` to `fpath` once | Same missing-dir tolerance; plain-directory check before touching `fpath` |
| `zsh_functions_init` | Single entry point wired by the managed `BEGIN/END zsh-functions` block | Cycle guard (`_ZSH_FUNCTIONS_INITED`); resolves the functions dir once from `${ZSH_FUNCTIONS_DIR:-$(brew --prefix)/share/zsh-functions}` and caches it so interactive startup never forks `brew` on the warm path; `autoload -Uz` each `*(N-.)` file |
| `brew_refresh_path` | Dynamic repair when Homebrew appears mid-session or its prefix is readable but not writable | Idempotent; safe to call manually or from `precmd`/`chpwd`; delegates to `path_prepend_unique` |

Existing example: `functions/mkcd` (no helpers needed — pure directory+cd logic).
Ported example: `functions/dirsize` (ported from the legacy
`~/.functions/dirsize.zsh` manual copy; keeps its `emulate -L zsh` +
parallel-`du` behavior, drops the hand-copy install).
