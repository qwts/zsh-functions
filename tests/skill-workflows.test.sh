#!/usr/bin/env bash
# Representative workflow and output-contract tests for the zsh-functions
# skill (ENG-0055 release-gate check 5). The shared cli-skill-gate runs them
# against the packaged zsh-profile through CLI_SKILL_GATE_EXECUTABLE; run
# directly, they use this checkout's bin/zsh-profile. Every write goes to a
# temporary directory.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ZP="${CLI_SKILL_GATE_EXECUTABLE:-$ROOT/bin/zsh-profile}"
SKILL="$ROOT/skills/zsh-functions/SKILL.md"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

# --- --version prints the bare release version --------------------------------
out="$("$ZP" --version 2>"$TEST_DIR/err")"
[[ "$out" == "$(tr -d '[:space:]' <"$ROOT/VERSION")" ]] || fail "--version prints VERSION (got '$out')"
[[ ! -s "$TEST_DIR/err" ]] || fail "--version writes nothing to stderr"

# --- skill-path reports the bundled skill and its source commit ----------------
"$ZP" skill-path >"$TEST_DIR/skill"
bundle="$(sed -n 1p "$TEST_DIR/skill")"
# A packaged release must name its source commit; only a direct run from a
# tree with no git metadata may report unknown.
commit_re='commit ([0-9a-f]{40}|unknown)'
[[ -z "${CLI_SKILL_GATE_EXECUTABLE:-}" ]] || commit_re='commit [0-9a-f]{40}'
sed -n 2p "$TEST_DIR/skill" | grep -Eqx "$commit_re" || fail "skill-path reports the source commit"
cmp -s "$bundle/SKILL.md" "$SKILL" || fail "bundled SKILL.md matches the source"

# --- ensure-path-block writes once, then reports unchanged ---------------------
ZSHENV="$TEST_DIR/.zshenv"
"$ZP" ensure-path-block --file "$ZSHENV" --name demo --dir /opt/demo/bin | grep -q '^ensured block "demo"' \
    || fail "first ensure-path-block reports ensured"
"$ZP" ensure-path-block --file "$ZSHENV" --name demo --dir /opt/demo/bin | grep -q '^unchanged block "demo"' \
    || fail "rerun reports unchanged"
"$ZP" lint "$ZSHENV" >"$TEST_DIR/lint" || fail "lint passes a file zsh-profile wrote"
[[ ! -s "$TEST_DIR/lint" ]] || fail "clean lint prints nothing"

# --- lint reports findings on stdout and exits 1 -------------------------------
printf 'export PATH=/x:$PATH\n' >"$TEST_DIR/bad"
set +e
"$ZP" lint "$TEST_DIR/bad" >"$TEST_DIR/lint" 2>"$TEST_DIR/err"
status=$?
set -e
[[ $status -eq 1 ]] || fail "lint exits 1 on findings"
grep -q ':1: unguarded PATH export' "$TEST_DIR/lint" || fail "lint prints file:line: finding"
printf 'top\n# BEGIN demo\nx\n\n' >"$TEST_DIR/eof"
"$ZP" lint "$TEST_DIR/eof" >"$TEST_DIR/lint" && fail "lint exits 1 on EOF findings"
grep -Fqx "$TEST_DIR/eof:2: unterminated block at EOF: # BEGIN demo" "$TEST_DIR/lint" || fail "EOF block finding names its line"
grep -Fqx "$TEST_DIR/eof:4: trailing blank line(s) at EOF" "$TEST_DIR/lint" || fail "EOF blank finding names its line"

# --- errors go to stderr with the program prefix -------------------------------
set +e
"$ZP" no-such-command >"$TEST_DIR/out" 2>"$TEST_DIR/err"
status=$?
set -e
[[ $status -eq 1 && ! -s "$TEST_DIR/out" ]] || fail "unknown command exits 1 with no stdout"
[[ "$(cat "$TEST_DIR/err")" == "zsh-profile: unknown command: no-such-command" ]] || fail "error format"
set +e
"$ZP" ensure-block --file >"$TEST_DIR/out" 2>"$TEST_DIR/err"
status=$?
set -e
[[ $status -eq 1 && ! -s "$TEST_DIR/out" ]] || fail "missing option value exits 1 with no stdout"
[[ "$(cat "$TEST_DIR/err")" == "zsh-profile: missing value for --file" ]] || fail "missing value error format"

# --- every command the skill classifies is documented by --help ----------------
help="$("$ZP" --help)"
while read -r command; do
    grep -Eq "^  ${command}( |$)" <<<"$help" || fail "--help documents $command"
done < <(grep -E '^\| (read-only|local-write) \|' "$SKILL" | cut -d'|' -f3 | grep -oE '`[a-z-]+`' | tr -d '`' | grep -v '^-')

echo "skill-workflows: ok"
