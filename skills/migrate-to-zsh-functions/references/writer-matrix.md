# Writer matrix

Where a migration change lands. Edit templates and writers — never live `~/`
files directly; `managed-machine setup zsh` applies template changes.

| File written | Writers today | Change lands in |
|---|---|---|
| `~/.zshrc` | `managed-machine-config/dotfiles/zsh/.zshrc` template + `managed-machine/lib/install.sh` `ensure_*_in_zshrc`, vendor installers (opencode/antigravity-style leaks), user | Template block + `ensure_zsh_functions_in_zshrc` shim; re-run `setup zsh` to re-own vendor leaks |
| `~/.zshenv` | `managed-machine-config/dotfiles/zsh/.zshenv` template (minimal by design), `agent-bot-identity/shell-path.mjs` `ensureExecutablePath`/`installGhShim`, legacy `~/.functions` sourcing loop | Template stays minimal; harness lines migrate to guarded form via `ensurePathLine` with shared markers; legacy loop replaced by `autoload` path |
| `~/.zprofile` | `managed-machine-config/dotfiles/zsh/.zprofile` template, Homebrew installer (`brew shellenv`), `agent-bot-identity` login-priority line | Template + forwarded `brew shellenv` lines only; preserve login-ordering (`.zprofile` resolves before `brew shellenv` consumers) |
| `~/.functions/*` | Hand-copied files (e.g. `dirsize.zsh`) | Port into `functions/` via `add-zsh-function`, then delete the hand copy |
| `$(brew --prefix)/share/zsh-functions/*` | `Formula/zsh-functions.rb` (`Dir["functions/*"]`) | Source of truth after `v*` tag + `brew reinstall` |

Cross-cutting: honor `ZDOTDIR` (zsh reads `$ZDOTDIR/.zshenv`, never
`$HOME/.zshenv`, when set); keep harness `.zshenv` (non-login non-interactive)
vs `.zprofile` (login ordering) split — both registrations stay, neither
replaces the other.
