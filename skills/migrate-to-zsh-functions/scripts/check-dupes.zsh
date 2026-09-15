#!/usr/bin/env zsh
# check-dupes.zsh — prove the init pattern never duplicates path/fpath.
#
# Usage: check-dupes.zsh [functions-dir]   (default: <repo>/functions)
#
# Read-only: creates only mktemp scratch dirs, removes them on exit. No
# network, no secrets, never touches $HOME or live dotfiles.
#
# What it checks:
#   1. `zsh -n` syntax over every file in the functions dir (skipped with a
#      note when the dir does not exist yet).
#   2. Double application of path_prepend_unique/fpath_add_unique with the
#      same dir yields exactly one entry in each array (clean `zsh -f` shell).
#   3. A missing/unreadable dir is tolerated (exit 0, nothing added) so
#      read-only brew prefixes keep working.
#
# When functions/path_prepend_unique and functions/fpath_add_unique exist they
# are autoloaded and tested for real; otherwise the exact guard expressions
# from the api-catalog are exercised as the pattern self-test.

emulate -L zsh
setopt errexit nounset pipefail

FUNC_DIR="${1:-${0:A:h}/../../../functions}"
FUNC_DIR="${FUNC_DIR:a}"
failures=0
note() { print -r -- "check-dupes: $*"; }
fail() { print -r -- "check-dupes FAIL: $*"; failures=$(( failures + 1 )); }

# 1. Syntax check.
if [[ -d "$FUNC_DIR" ]]; then
  integer n=0
  for f in "$FUNC_DIR"/*(N-.); do
    n=$(( n + 1 ))
    zsh -n "$f" || fail "syntax: $f"
  done
  note "syntax ok ($n files): $FUNC_DIR"
else
  note "no functions dir at $FUNC_DIR, skipping syntax check"
fi

work="$(mktemp -d)"
fixture="$(mktemp -d)"
trap 'rm -rf "$work" "$fixture"' EXIT
inner="$work/inner.zsh"

# 2+3. Idempotency + missing-dir tolerance in a clean shell.
cat > "$inner" <<'INNER_EOF'
emulate -L zsh
setopt nounset pipefail
func_dir="$1"
target="$2"
path=(/usr/bin /bin)
fpath=(/usr/share/zsh/site-functions)
# No `typeset -U` here by design: uniqueness must come from the helpers'
# guards, so a helper that unconditionally prepends fails this test.
if [[ -f "$func_dir/path_prepend_unique" && -f "$func_dir/fpath_add_unique" ]]; then
  fpath=("$func_dir" $fpath)
  autoload -Uz path_prepend_unique fpath_add_unique
  repeat 2; do
    path_prepend_unique "$target"
    fpath_add_unique "$target"
  done
  # Missing dir must be tolerated.
  path_prepend_unique /nonexistent-check-dupes-dir || exit 1
  fpath_add_unique /nonexistent-check-dupes-dir || exit 1
else
  # Pattern self-test: the exact guards the helpers must implement.
  repeat 2; do
    if [[ -d "$target" ]]; then
      (( ${path[(I)$target]} )) || path=("$target" $path)
      (( ${fpath[(I)$target]} )) || fpath=("$target" $fpath)
    fi
  done
fi
integer np=0 nf=0 missing=0
for p in $path; do
  [[ "$p" == "$target" ]] && np=$(( np + 1 ))
  [[ "$p" == /nonexistent-check-dupes-dir ]] && missing=$(( missing + 1 ))
done
for p in $fpath; do
  [[ "$p" == "$target" ]] && nf=$(( nf + 1 ))
  [[ "$p" == /nonexistent-check-dupes-dir ]] && missing=$(( missing + 1 ))
done
print -r -- "path_count=$np fpath_count=$nf missing_leaked=$missing"
[[ "$np" -eq 1 && "$nf" -eq 1 && "$missing" -eq 0 ]]
INNER_EOF

if out="$(zsh -f "$inner" "$FUNC_DIR" "$fixture" 2>&1)"; then
  note "idempotency ok ($out)"
else
  fail "idempotency ($out)"
fi

if (( failures > 0 )); then
  print -r -- "check-dupes: $failures failure(s)" >&2
  exit 1
fi
note "all checks passed"
