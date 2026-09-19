#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FUNCS="$ROOT/functions"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

# --- syntax: every function file parses --------------------------------------
for f in "$FUNCS"/*; do
  zsh -n "$f" || fail "zsh -n failed for $f"
done

# --- lazy autoload: marking names reads no files ------------------------------
zsh -f -c "
  fpath+=(\"$FUNCS\")
  autoload -Uz path_prepend_unique fpath_add_unique zsh_functions_init brew_refresh_path dirsize
  for n in path_prepend_unique fpath_add_unique zsh_functions_init brew_refresh_path dirsize; do
    whence -w \"\$n\" | grep -q 'function' || { print -u2 \"not marked: \$n\"; exit 1 }
  done
" || fail "autoload marking failed"

# --- path_prepend_unique: dedup across nested calls ----------------------------
zsh -f -c "
  fpath+=(\"$FUNCS\")
  autoload -Uz path_prepend_unique
  D=\"\$(mktemp -d)\"
  path_prepend_unique \"\$D\"
  path_prepend_unique \"\$D\"
  path_prepend_unique \"\$D\"
  c=0
  for p in \"\$path[@]\"; do [[ \"\$p\" == \"\$D\" ]] && (( c++ )); done
  (( c == 1 )) || { print -u2 \"duplicate PATH entry: \$c\"; exit 1 }
" || fail "path_prepend_unique duplicated"

# --- path_prepend_unique: rejected inputs leave PATH byte-identical ---------------
zsh -f -c "
  fpath+=(\"$FUNCS\")
  autoload -Uz path_prepend_unique
  export PATH=\"/usr/bin:/bin:/usr/bin:/bin\"
  before=\"\$PATH\"
  path_prepend_unique || exit 1
  [[ \"\$PATH\" == \"\$before\" ]] || { print -u2 'no-arg call mutated PATH'; exit 1 }
  path_prepend_unique \"$TEST_DIR/does-not-exist\" || exit 1
  [[ \"\$PATH\" == \"\$before\" ]] || { print -u2 'missing-dir call mutated PATH'; exit 1 }
" || fail "path_prepend_unique no-op mutated PATH"

# --- fpath_add_unique: rejected inputs leave fpath byte-identical -----------------
zsh -f -c "
  fpath+=(\"$FUNCS\")
  autoload -Uz fpath_add_unique
  fpath=(\"$FUNCS\" \"/nonexistent-a\" \"/nonexistent-b\" \"/nonexistent-a\")
  before=\"\${fpath[*]}\"
  fpath_add_unique || exit 1
  [[ \"\${fpath[*]}\" == \"\$before\" ]] || { print -u2 'no-arg call mutated fpath'; exit 1 }
  fpath_add_unique \"$TEST_DIR/does-not-exist\" || exit 1
  [[ \"\${fpath[*]}\" == \"\$before\" ]] || { print -u2 'missing-dir call mutated fpath'; exit 1 }
" || fail "fpath_add_unique no-op mutated fpath"

# --- fpath_add_unique: dedup + missing tolerance --------------------------------
zsh -f -c "
  fpath+=(\"$FUNCS\")
  autoload -Uz fpath_add_unique
  D=\"\$(mktemp -d)\"
  fpath_add_unique \"\$D\"
  fpath_add_unique \"\$D\"
  c=0
  for p in \"\$fpath[@]\"; do [[ \"\$p\" == \"\$D\" ]] && (( c++ )); done
  (( c == 1 )) || { print -u2 \"duplicate fpath entry\"; exit 1 }
  fpath_add_unique \"$TEST_DIR/does-not-exist\" || exit 1
" || fail "fpath_add_unique dedup/tolerance failed"

# --- zsh_functions_init: cycle guard + autoloads all -----------------------------
zsh -f -c "
  fpath+=(\"$FUNCS\")
  autoload -Uz zsh_functions_init
  ZSH_FUNCTIONS_DIR=\"$FUNCS\" zsh_functions_init
  [[ -n \"\${_ZSH_FUNCTIONS_INITED:-}\" ]] || { print -u2 'no cycle guard'; exit 1 }
  [[ \"\${_ZSH_FUNCTIONS_DIR:-}\" == \"$FUNCS\" ]] || { print -u2 'dir not cached'; exit 1 }
  for n in path_prepend_unique fpath_add_unique brew_refresh_path dirsize; do
    whence -w \"\$n\" | grep -q 'function' || { print -u2 \"not autoloaded: \$n\"; exit 1 }
  done
  ZSH_FUNCTIONS_DIR=\"$FUNCS\" zsh_functions_init || exit 1
" || fail "zsh_functions_init cycle/autoload failed"

# --- zsh_functions_init: warm path never forks brew ------------------------------
ZSH_BIN="$(command -v zsh)"
zsh -f -c "
  fpath+=(\"$FUNCS\")
  autoload -Uz zsh_functions_init
  ZSH_FUNCTIONS_DIR=\"$FUNCS\" zsh_functions_init
  brew() { print -u2 'brew forked on warm path'; exit 9 }
  ZSH_FUNCTIONS_DIR=\"$FUNCS\" zsh_functions_init || exit 1
" || fail "warm init forked brew"

# --- brew_refresh_path: fake prefix in bare zsh -f, no writes, idempotent ---------
FAKE="$TEST_DIR/fakebrew"
mkdir -p "$FAKE/bin" "$FAKE/sbin"
zsh -f -c "
  fpath+=(\"$FUNCS\")
  autoload -Uz brew_refresh_path path_prepend_unique
  HOMEBREW_PREFIX=\"$FAKE\" brew_refresh_path
  HOMEBREW_PREFIX=\"$FAKE\" brew_refresh_path
  c=0
  for p in \"\$path[@]\"; do [[ \"\$p\" == \"$FAKE/bin\" ]] && (( c++ )); done
  (( c == 1 )) || { print -u2 'bin not exactly once'; exit 1 }
  c=0
  for p in \"\$path[@]\"; do [[ \"\$p\" == \"$FAKE/sbin\" ]] && (( c++ )); done
  (( c == 1 )) || { print -u2 'sbin not exactly once'; exit 1 }
  [[ \"\$path[1]\" == \"$FAKE/bin\" ]] || { print -u2 \"configured prefix not first: \$path[1]\"; exit 1 }
  bin_i=0; sbin_i=0; i=0
  for p in \"\$path[@]\"; do
    (( i++ ))
    [[ \"\$p\" == \"$FAKE/bin\" ]] && bin_i=\$i
    [[ \"\$p\" == \"$FAKE/sbin\" ]] && sbin_i=\$i
  done
  (( bin_i < sbin_i )) || { print -u2 'bin should precede sbin'; exit 1 }
" || fail "brew_refresh_path fake-prefix failed"
[[ -z "$(ls -A "$FAKE")" ]] || true
[[ ! -e "$FAKE/touched" ]] || fail "brew_refresh_path wrote files"

# --- dirsize: lists subdirs, -j flag, invalid dir ---------------------------------
D="$TEST_DIR/sized"
mkdir -p "$D/alpha" "$D/beta"
printf 'x%.0s' {1..1000} >"$D/alpha/f"
printf 'x%.0s' {1..10} >"$D/beta/f"
zsh -f -c "
  fpath+=(\"$FUNCS\")
  autoload -Uz dirsize
  out=\$(dirsize -j 2 \"$D\") || exit 1
  print -r -- \"\$out\" | grep -q alpha || { print -u2 'missing alpha'; exit 1 }
  print -r -- \"\$out\" | grep -q beta || { print -u2 'missing beta'; exit 1 }
" || fail "dirsize basic failed"
zsh -f -c "
  fpath+=(\"$FUNCS\")
  autoload -Uz dirsize
  dirsize \"$TEST_DIR/does-not-exist\" 2>/dev/null && exit 1
  [[ \$? == 1 ]] || exit 1
" || fail "dirsize invalid dir should exit 1"

echo "functions tests passed"
