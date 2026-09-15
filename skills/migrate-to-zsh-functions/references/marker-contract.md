# Marker contract

One block format shared by every writer (`managed-machine/lib/install.sh`,
`local-bin/install`, `agent-bot-identity/shell-path.mjs`). Copy the mechanism
that already works for `# BEGIN local-bin`.

## Rules

- Markers are whole-line, column-zero, byte-identical across writers:
  `# BEGIN zsh-functions` … `# END zsh-functions`.
- Writers strip only their own block (`awk '$0==BEGIN{skip=1} $0==END{skip=0} !skip'`)
  and append a fresh block; they never touch lines outside the markers.
- Readers match the marker against the **whole file**, so a hand-moved block is
  still recognized and never duplicated.
- Block body calls `zsh_functions_init` (see the [api-catalog](../../add-zsh-function/references/api-catalog.md)); it contains no inline
  PATH/fpath logic beyond the init call, so behavior changes ship with the
  functions, not with every writer.

## Canonical body

```zsh
# BEGIN zsh-functions
if [[ -f "${ZSH_FUNCTIONS_DIR:-$(brew --prefix 2>/dev/null)/share/zsh-functions}/zsh_functions_init" ]]; then
  fpath=("${ZSH_FUNCTIONS_DIR:-$(brew --prefix)/share/zsh-functions}" $fpath)
  autoload -Uz zsh_functions_init 2>/dev/null && zsh_functions_init
fi
# END zsh-functions
```

Refinement at implementation time: prefer the cached `ZSH_FUNCTIONS_DIR` form
so warm interactive shells never fork `brew`; keep the `brew --prefix`
fallback for machines whose setup has not run yet.
