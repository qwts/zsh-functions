#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ZP="$ROOT/bin/zsh-profile"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

ZSHRC="$TEST_DIR/.zshrc"

fail() { echo "FAIL: $1" >&2; exit 1; }

# --- ensure-block: append to empty file produces exactly the block -----------
printf 'line one\nline two\n' | "$ZP" ensure-block --file "$ZSHRC" --name demo >/dev/null
printf '# BEGIN demo\nline one\nline two\n# END demo\n' | cmp - "$ZSHRC" \
    || fail "empty file gets block with no leading blank"

# --- ensure-block: appended to content gets exactly one blank separator ------
printf 'alias a=1\n' >"$ZSHRC"
printf 'body\n' | "$ZP" ensure-block --file "$ZSHRC" --name demo >/dev/null
printf 'alias a=1\n\n# BEGIN demo\nbody\n# END demo\n' | cmp - "$ZSHRC" \
    || fail "new block separated by one blank line"

# --- ensure-block: idempotent, byte-identical ---------------------------------
cp "$ZSHRC" "$TEST_DIR/before"
printf 'body\n' | "$ZP" ensure-block --file "$ZSHRC" --name demo >/dev/null
cmp -s "$TEST_DIR/before" "$ZSHRC" || fail "second ensure-block changed the file"

# --- ensure-block: in-place rewrite preserves position, no whitespace growth --
printf 'top\n\n# BEGIN demo\nold\n# END demo\n\nbottom\n' >"$ZSHRC"
printf 'new\n' | "$ZP" ensure-block --file "$ZSHRC" --name demo >/dev/null
printf 'top\n\n# BEGIN demo\nnew\n# END demo\n\nbottom\n' | cmp - "$ZSHRC" \
    || fail "rewrite must stay in place"

# --- ensure-block: repeated rewrites never grow blank lines -------------------
for i in 1 2 3 4 5; do
    printf 'v%s\n' "$i" | "$ZP" ensure-block --file "$ZSHRC" --name demo >/dev/null
done
[[ "$(grep -c '^$' "$ZSHRC")" == "2" ]] || fail "blank lines accumulated over rewrites"

# --- ensure-block: pre-existing rot is not made worse; append strips trailing -
printf 'top\n\n\n\n\n\n\n' >"$ZSHRC"
printf 'x\n' | "$ZP" ensure-block --file "$ZSHRC" --name tail >/dev/null
printf 'top\n\n# BEGIN tail\nx\n# END tail\n' | cmp - "$ZSHRC" \
    || fail "append must strip trailing blank lines first"

# --- ensure-block: duplicate same-name blocks collapse to one -----------------
printf '# BEGIN d\na\n# END d\nmid\n# BEGIN d\nb\n# END d\n' >"$ZSHRC"
printf 'c\n' | "$ZP" ensure-block --file "$ZSHRC" --name d >/dev/null
[[ "$(grep -c '^# BEGIN d$' "$ZSHRC")" == "1" ]] || fail "duplicate block not collapsed"
printf '# BEGIN d\nc\n# END d\nmid\n' | cmp - "$ZSHRC" \
    || fail "duplicate collapse keeps first site with new body"

# --- ensure-block --absorb-marker: loose matching lines removed ---------------
printf 'top\nexport PATH="$HOME/.local/bin:$PATH"  # agent-bot CLI\nother\n' >"$ZSHRC"
printf 'path=("$HOME/.local/bin" $path)\n' \
    | "$ZP" ensure-block --file "$ZSHRC" --name agent-bot-cli \
        --absorb-marker '# agent-bot CLI' >/dev/null
! grep -qF '# agent-bot CLI' "$ZSHRC" || fail "absorbed line still present"
printf 'top\nother\n\n# BEGIN agent-bot-cli\npath=("$HOME/.local/bin" $path)\n# END agent-bot-cli\n' \
    | cmp - "$ZSHRC" || fail "absorb + append output wrong"
# second run: nothing left to absorb, no change
cp "$ZSHRC" "$TEST_DIR/before"
printf 'path=("$HOME/.local/bin" $path)\n' \
    | "$ZP" ensure-block --file "$ZSHRC" --name agent-bot-cli \
        --absorb-marker '# agent-bot CLI' >/dev/null
cmp -s "$TEST_DIR/before" "$ZSHRC" || fail "absorb is not idempotent"

# --- absorb never deletes the marker inside another managed block --------------
printf '# BEGIN other\nline mentioning MARKER inside\n# END other\nloose MARKER here\n' >"$ZSHRC"
printf 'x\n' | "$ZP" ensure-block --file "$ZSHRC" --name mine \
    --absorb-marker 'MARKER' >/dev/null
grep -qxF 'line mentioning MARKER inside' "$ZSHRC" \
    || fail "absorb deleted a line inside a managed block"
! grep -qxF 'loose MARKER here' "$ZSHRC" || fail "absorb missed the loose line"

# --- ensure-block: unterminated target block is an error -----------------------
printf '# BEGIN broken\nbody\n' >"$ZSHRC"
if printf 'x\n' | "$ZP" ensure-block --file "$ZSHRC" --name broken >/dev/null 2>&1; then
    fail "unterminated block must fail"
fi

# --- ensure-block: file mode preserved ----------------------------------------
mode_of() { stat -f %Lp "$1" 2>/dev/null || stat -c %a "$1"; }
printf 'mode test\n' >"$ZSHRC"
chmod 640 "$ZSHRC"
printf 'x\n' | "$ZP" ensure-block --file "$ZSHRC" --name m >/dev/null
[[ "$(mode_of "$ZSHRC")" == "640" ]] || fail "mode not preserved"

# --- remove-block: block removed, boundary blanks collapse ---------------------
printf 'top\n\n# BEGIN gone\nx\n# END gone\n\nbottom\n' >"$ZSHRC"
"$ZP" remove-block --file "$ZSHRC" --name gone >/dev/null
printf 'top\n\nbottom\n' | cmp - "$ZSHRC" || fail "remove-block left extra blanks"

# --- remove-block: block at EOF strips trailing blanks --------------------------
printf 'top\n\n# BEGIN tail\nx\n# END tail\n' >"$ZSHRC"
"$ZP" remove-block --file "$ZSHRC" --name tail >/dev/null
printf 'top\n' | cmp - "$ZSHRC" || fail "remove-block at EOF left trailing blanks"

# --- remove-block: absent block is a no-op --------------------------------------
printf 'top\n' >"$ZSHRC"
"$ZP" remove-block --file "$ZSHRC" --name none >/dev/null
printf 'top\n' | cmp - "$ZSHRC" || fail "remove-block touched a file with no block"

# --- remove-block: unrelated edge whitespace is preserved ------------------------
printf '\n\ntop\n\n# BEGIN mid\nx\n# END mid\n\nbottom\n\n\n' >"$ZSHRC"
"$ZP" remove-block --file "$ZSHRC" --name mid >/dev/null
printf '\n\ntop\n\nbottom\n\n\n' | cmp - "$ZSHRC" \
    || fail "remove-block rewrote edge blanks unrelated to the block"

# --- ensure-line: appends once, repairs missing trailing newline ----------------
printf 'no newline' >"$ZSHRC"
"$ZP" ensure-line --file "$ZSHRC" --marker '# my marker' \
    --line 'export X=1  # my marker' >/dev/null
printf 'no newline\nexport X=1  # my marker\n' | cmp - "$ZSHRC" \
    || fail "ensure-line must repair missing trailing newline"
"$ZP" ensure-line --file "$ZSHRC" --marker '# my marker' \
    --line 'export X=1  # my marker' >/dev/null
[[ "$(grep -cF '# my marker' "$ZSHRC")" == "1" ]] || fail "ensure-line duplicated"

# --- ensure-path-block: standard dedup guard body --------------------------------
: >"$ZSHRC"
"$ZP" ensure-path-block --file "$ZSHRC" --name local-bin --dir '${HOME}/.local/bin' >/dev/null
printf 'case ":${PATH}:" in\n    *":${HOME}/.local/bin:"*) ;;\n    *) export PATH="${HOME}/.local/bin:${PATH}" ;;\nesac\n' \
    >"$TEST_DIR/expected-body"
printf '# BEGIN local-bin\n' >"$TEST_DIR/expected"
cat "$TEST_DIR/expected-body" >>"$TEST_DIR/expected"
printf '# END local-bin\n' >>"$TEST_DIR/expected"
cmp "$TEST_DIR/expected" "$ZSHRC" || fail "ensure-path-block body mismatch"

: >"$ZSHRC"
"$ZP" ensure-path-block --file "$ZSHRC" --name app --dir /opt/x/bin --append >/dev/null
grep -qxF '    *) export PATH="${PATH}:/opt/x/bin" ;;' "$ZSHRC" \
    || fail "--append body wrong"

# --- lint: clean file exits 0, problems are reported -----------------------------
printf 'top\n\n# BEGIN ok\nx\n# END ok\n' >"$ZSHRC"
"$ZP" lint "$ZSHRC" >/dev/null || fail "lint flagged a clean file"

lint_out() { "$ZP" lint "$1" 2>&1 || true; }

printf 'export PATH="$HOME/.local/bin:$PATH"\n' >"$ZSHRC"
"$ZP" lint "$ZSHRC" >/dev/null 2>&1 && fail "lint missed unguarded export"
grep -q 'unguarded PATH export' <<<"$(lint_out "$ZSHRC")" \
    || fail "lint message missing"

printf '# BEGIN a\nx\n# END a\n# BEGIN a\ny\n# END a\n' >"$ZSHRC"
grep -q 'duplicate block' <<<"$(lint_out "$ZSHRC")" || fail "lint missed dup block"

printf '# BEGIN open\nx\n' >"$ZSHRC"
grep -q 'unterminated' <<<"$(lint_out "$ZSHRC")" || fail "lint missed orphan BEGIN"

printf '# BEGIN a\nx\n# END b\n' >"$ZSHRC"
grep -q 'does not close' <<<"$(lint_out "$ZSHRC")" || fail "lint missed mismatched END"

printf 'a\n\n\n\nb\n' >"$ZSHRC"
grep -q 'blank run' <<<"$(lint_out "$ZSHRC")" || fail "lint missed blank rot"

printf 'path=("$HOME/x" $path)\n' >"$ZSHRC"
grep -q 'unguarded path assignment' <<<"$(lint_out "$ZSHRC")" \
    || fail "lint missed unguarded path="

# --- compact: collapses runs, strips leading/trailing blanks ---------------------
printf '\n\na\n\n\n\n\n\n\n\n\nb\n\n\n' >"$ZSHRC"
"$ZP" compact "$ZSHRC" >/dev/null
printf 'a\n\nb\n' | cmp - "$ZSHRC" || fail "compact did not normalize blanks"
"$ZP" compact "$ZSHRC" >/dev/null
printf 'a\n\nb\n' | cmp - "$ZSHRC" || fail "compact not idempotent"

# --- end-to-end: a realistic .zshrc migration -------------------------------------
cat >"$ZSHRC" <<'EOF'
# Managed by managed-machine/setup-zsh.



















# BEGIN local-bin
case ":${PATH}:" in
    *":${HOME}/.local/bin:"*) ;;
    *) export PATH="${HOME}/.local/bin:${PATH}" ;;
esac
# END local-bin

# BEGIN nvm
export NVM_DIR="${NVM_DIR:-${HOME}/.nvm}"
case "$(command -v node 2>/dev/null)" in
    "${NVM_DIR}/versions/"*) [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" --no-use ;;
    *) [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" ;;
esac
# END nvm
EOF
"$ZP" compact "$ZSHRC" >/dev/null
[[ "$(grep -c '^$' "$ZSHRC")" == "2" ]] || fail "compact left rot in realistic file"
printf 'typeset -U path PATH\npath=("$HOME/.config/agent-bot/bin" $path)\n' \
    | "$ZP" ensure-block --file "$ZSHRC" --name agent-bot-gh-shim >/dev/null
"$ZP" lint "$ZSHRC" >/dev/null || fail "post-migration file should lint clean"
if command -v zsh >/dev/null 2>&1; then
    zsh -n "$ZSHRC" || fail "resulting file is not valid zsh"
fi

echo "zsh-profile tests passed"
