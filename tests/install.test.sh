#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

export HOME="$TEST_DIR/home"
unset XDG_DATA_HOME ZDOTDIR
mkdir -p "$HOME"

FUNCS_DEST="$HOME/.local/share/zsh/functions"
MANIFEST="$HOME/.config/zsh-functions/linked-functions"
ZSHENV="$HOME/.zshenv"

fail() { echo "FAIL: $1" >&2; exit 1; }

# --- fixture .zshenv: unrelated lines + legacy eager-sourcing loop ------------
cat >"$ZSHENV" <<'EOF'
# my own header
export EDITOR=vim

# zsh functions folder
if [[ -d "$HOME/.functions" ]]; then
  fpath=("$HOME/.functions" $fpath)
  for _func_file in "$HOME"/.functions/*(N); do
    [[ -f "$_func_file" ]] && . "$_func_file"
  done
  unset _func_file
fi
EOF

"$ROOT/install" >/dev/null || fail "install failed"

# --- symlinks + manifest -------------------------------------------------------
for n in mkcd path_prepend_unique fpath_add_unique zsh_functions_init brew_refresh_path dirsize; do
  [[ -L "$FUNCS_DEST/$n" ]] || fail "missing link: $n"
  [[ "$(readlink "$FUNCS_DEST/$n")" == "$ROOT/functions/$n" ]] || fail "bad target: $n"
done
printf 'brew_refresh_path\ndirsize\nfpath_add_unique\nmkcd\npath_prepend_unique\nzsh_functions_init\n' \
  | cmp - "$MANIFEST" || fail "manifest mismatch"

# --- loader block: exact markers, init delegation, legacy gone ------------------
grep -qxF '# BEGIN zsh-functions' "$ZSHENV" || fail "missing BEGIN marker"
grep -qxF '# END zsh-functions' "$ZSHENV" || fail "missing END marker"
grep -qF 'zsh_functions_init' "$ZSHENV" || fail "loader does not delegate to init"
grep -qF '_func_file' "$ZSHENV" && fail "legacy loop survived"
grep -qF '.functions' "$ZSHENV" && fail "legacy marker survived"
grep -qF '# zsh functions folder' "$ZSHENV" && fail "legacy header survived"
[[ "$(grep -cx 'fi' "$ZSHENV")" == "1" ]] || fail "stray fi from legacy loop"
[[ "$(grep -cx 'done' "$ZSHENV")" == "0" ]] || fail "stray done from legacy loop"
grep -qE '^[[:space:]]*(\.|source)[[:space:]]' "$ZSHENV" && fail "eager sourcing present"
grep -qF '# my own header' "$ZSHENV" || fail "unrelated header lost"
grep -qF 'export EDITOR=vim' "$ZSHENV" || fail "unrelated export lost"
ls "$ZSHENV".*.bak >/dev/null || fail "no .zshenv backup taken"
[[ -L "$HOME/.local/bin/zsh-profile" ]] || fail "zsh-profile not linked"
[[ "$(readlink "$HOME/.local/bin/zsh-profile")" == "$ROOT/bin/zsh-profile" ]] \
  || fail "zsh-profile target wrong"

# --- idempotent re-run: byte-identical, no extra backup --------------------------
cp "$ZSHENV" "$TEST_DIR/zshenv.before"
baks_before="$(ls "$ZSHENV".*.bak | wc -l | tr -d ' ')"
"$ROOT/install" >/dev/null || fail "re-run failed"
cmp -s "$TEST_DIR/zshenv.before" "$ZSHENV" || fail "re-run changed .zshenv"
baks_after="$(ls "$ZSHENV".*.bak | wc -l | tr -d ' ')"
[[ "$baks_after" == "$baks_before" ]] || fail "re-run took another backup"

# --- prune: stale manifest entry + renamed link removed, rest intact --------------
ln -sfn "$ROOT/functions/dirsize" "$FUNCS_DEST/oldname"
printf 'oldname\n' >>"$MANIFEST"
"$ROOT/install" >/dev/null || fail "prune run failed"
[[ ! -e "$FUNCS_DEST/oldname" ]] || fail "stale link not pruned"
grep -qxF 'oldname' "$MANIFEST" && fail "stale manifest entry kept"
[[ -L "$FUNCS_DEST/dirsize" ]] || fail "prune removed a live link"

# --- ZDOTDIR override: block lands in $ZDOTDIR/.zshenv -----------------------------
export ZDOTDIR="$TEST_DIR/zdot"
mkdir -p "$ZDOTDIR"
"$ROOT/install" >/dev/null || fail "ZDOTDIR run failed"
grep -qxF '# BEGIN zsh-functions' "$ZDOTDIR/.zshenv" || fail "ZDOTDIR block missing"
unset ZDOTDIR

# --- fresh non-interactive zsh: dirsize works, zero eager file reads ---------------
printf 'echo CANARY-SOURCED >&2\nreturn 1\n' >"$FUNCS_DEST/_canary"
SIZED="$TEST_DIR/sized"
mkdir -p "$SIZED/alpha" "$SIZED/beta"
printf 'x%.0s' {1..100} >"$SIZED/alpha/f"
out="$(HOME="$TEST_DIR/home" zsh -c 'dirsize "$0"' "$SIZED" 2>"$TEST_DIR/stderr")" \
  || fail "fresh zsh dirsize failed"
grep -q alpha <<<"$out" || fail "dirsize output wrong"
grep -q CANARY-SOURCED "$TEST_DIR/stderr" && fail "a function file was read eagerly"
rm -f "$FUNCS_DEST/_canary"

echo "install tests passed"
