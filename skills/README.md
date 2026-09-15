# Skills

Agent skills owned by this repo. Each `SKILL.md` carries its own install line;
symlink the skill directory into the harness so a `git pull` here updates every
machine, rather than copying and drifting:

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
ln -sfn "$REPO_ROOT/skills/<name>" ~/.claude/skills/<name>
```

These skills are also cataloged by link in `dev-steward/skills/README.md`
(never copied there).

## Available skills

- [add-zsh-function](add-zsh-function/SKILL.md) — author a new zsh function:
  `functions/<name>` per `AGENTS.md`, reuse of the API catalog, formula and
  `v*` tag release.
- [migrate-to-zsh-functions](migrate-to-zsh-functions/SKILL.md) — convert
  legacy `~/.functions` loops, vendor PATH leaks, and unguarded `export PATH`
  lines into guarded `BEGIN/END zsh-functions` blocks plus API calls.
- [audit-shell-writers](audit-shell-writers/SKILL.md) — read-only recon of who
  writes `.zshenv`/`.zprofile`/`.zshrc` across repos; run before migrating.
