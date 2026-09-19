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

# --- symlinks + manifest (name<TAB>target pairs) -----------------------------------
for n in mkcd path_prepend_unique fpath_add_unique zsh_functions_init brew_refresh_path dirsize; do
  [[ -L "$FUNCS_DEST/$n" ]] || fail "missing link: $n"
  [[ "$(readlink "$FUNCS_DEST/$n")" == "$ROOT/functions/$n" ]] || fail "bad target: $n"
done
[[ "$(wc -l < "$MANIFEST" | tr -d ' ')" == "6" ]] || fail "manifest line count wrong"
while IFS=$'\t' read -r name target; do
  [[ "$target" == "$ROOT/functions/$name" ]] || fail "manifest target wrong: $name"
done < "$MANIFEST"

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

# --- loader re-sourced in one shell: fpath gains no duplicate -----------------------
HOME="$TEST_DIR/home" zsh -f -c '
  source "$HOME/.zshenv"
  source "$HOME/.zshenv"
  c=0
  for p in "$fpath[@]"; do
    [[ "$p" == "$HOME/.local/share/zsh/functions" ]] && (( c++ ))
  done
  (( c == 1 )) || { print -u2 "fpath entry count: $c"; exit 1 }
' || fail "double-sourced loader duplicated fpath"

# --- idempotent re-run: byte-identical, no extra backup --------------------------
cp "$ZSHENV" "$TEST_DIR/zshenv.before"
baks_before="$(ls "$ZSHENV".*.bak | wc -l | tr -d ' ')"
"$ROOT/install" >/dev/null || fail "re-run failed"
cmp -s "$TEST_DIR/zshenv.before" "$ZSHENV" || fail "re-run changed .zshenv"
baks_after="$(ls "$ZSHENV".*.bak | wc -l | tr -d ' ')"
[[ "$baks_after" == "$baks_before" ]] || fail "re-run took another backup"

# --- prune: stale entries removed, foreign links kept -------------------------------
# Same-checkout rename.
ln -sfn "$ROOT/functions/dirsize" "$FUNCS_DEST/oldname"
printf 'oldname\t%s/functions/dirsize\n' "$ROOT" >>"$MANIFEST"
# Moved checkout: dangling target under the old root, ownership only via the
# recorded manifest target.
ln -sfn "/old/checkout/functions/gone" "$FUNCS_DEST/oldmoved"
printf 'oldmoved\t/old/checkout/functions/gone\n' >>"$MANIFEST"
# Foreign link with a stale manifest name: not ours, must survive.
ln -sfn "/usr/bin/true" "$FUNCS_DEST/foreign"
printf 'foreign\t/usr/bin/false\n' >>"$MANIFEST"
"$ROOT/install" >/dev/null || fail "prune run failed"
[[ ! -e "$FUNCS_DEST/oldname" && ! -L "$FUNCS_DEST/oldname" ]] || fail "stale link not pruned"
[[ ! -e "$FUNCS_DEST/oldmoved" && ! -L "$FUNCS_DEST/oldmoved" ]] || fail "moved-checkout link not pruned"
grep -qF 'oldname' "$MANIFEST" && fail "stale manifest entry kept"
grep -qF 'oldmoved' "$MANIFEST" && fail "moved manifest entry kept"
[[ "$(readlink "$FUNCS_DEST/foreign")" == "/usr/bin/true" ]] || fail "foreign link touched"
[[ -L "$FUNCS_DEST/dirsize" ]] || fail "prune removed a live link"

# --- XDG_DATA_HOME override: links + loader path + fresh zsh ------------------------
XDG_HOME="$TEST_DIR/xdghome"
mkdir -p "$XDG_HOME"
XDG_DATA_HOME="$TEST_DIR/xdg" HOME="$XDG_HOME" "$ROOT/install" >/dev/null \
  || fail "XDG install failed"
[[ "$(readlink "$TEST_DIR/xdg/zsh/functions/dirsize")" == "$ROOT/functions/dirsize" ]] \
  || fail "XDG link wrong"
grep -qF 'XDG_DATA_HOME' "$XDG_HOME/.zshenv" || fail "XDG loader path missing"
SIZED_XDG="$TEST_DIR/sized-xdg"
mkdir -p "$SIZED_XDG/only"
out="$(XDG_DATA_HOME="$TEST_DIR/xdg" HOME="$XDG_HOME" zsh -c 'dirsize "$0"' "$SIZED_XDG" 2>/dev/null)" \
  || fail "XDG fresh zsh dirsize failed"
grep -q only <<<"$out" || fail "XDG dirsize output wrong"

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

# --- symlinked .zshenv: link preserved, target edited --------------------------------
HOME2="$TEST_DIR/home2"
mkdir -p "$HOME2"
printf '# dotfiles target\nexport KEEP=1\n' >"$TEST_DIR/real-zshenv"
ln -s "$TEST_DIR/real-zshenv" "$HOME2/.zshenv"
HOME="$HOME2" "$ROOT/install" >/dev/null || fail "symlink install failed"
[[ -L "$HOME2/.zshenv" ]] || fail "symlink replaced by regular file"
grep -qxF '# BEGIN zsh-functions' "$TEST_DIR/real-zshenv" || fail "target missing block"
grep -qF 'export KEEP=1' "$TEST_DIR/real-zshenv" || fail "target content lost"

echo "install tests passed"
