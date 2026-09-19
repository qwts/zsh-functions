#!/usr/bin/env bash
# Shared helpers for the zsh-functions install script.

zsh_functions_config_dir() {
    printf '%s/.config/zsh-functions\n' "$HOME"
}

zsh_functions_data_dir() {
    printf '%s/zsh/functions\n' "${XDG_DATA_HOME:-$HOME/.local/share}"
}

# The .zshenv zsh actually reads: $ZDOTDIR wins when set, $HOME otherwise.
zsh_functions_zshenv() {
    printf '%s/.zshenv\n' "${ZDOTDIR:-$HOME}"
}

# Header line of the legacy hand-added ~/.functions sourcing loop. The
# remover below deletes from this line through its closing fi.
LEGACY_FUNCTIONS_LOOP_BEGIN="# zsh functions folder"

# Remove the legacy ~/.functions sourcing loop (header through its closing
# fi) from a zsh startup file. --absorb-marker cannot do this alone: the
# loop's trailing `done`/`fi` lines carry no identifying substring, and
# absorbing bare `done`/`fi` would eat unrelated code. Bounded and exact:
# only a block opened by the known header is removed; an unclosed header
# is left untouched and the function fails.
remove_legacy_functions_loop() {
    local file="$1" tmp
    [[ -f "$file" ]] || return 0
    tmp="$(mktemp)"
    # shellcheck disable=SC2064
    trap 'rm -f "$tmp"' RETURN
    if ! awk -v begin="$LEGACY_FUNCTIONS_LOOP_BEGIN" '
        $0 == begin { skipping = 1; found = 1; next }
        skipping && $0 == "fi" { skipping = 0; next }
        !skipping { print }
        END { if (!found) exit 0; exit skipping }
    ' "$file" >"$tmp"; then
        echo "note: legacy functions loop in $file has no closing fi — left untouched" >&2
        return 1
    fi
    if cmp -s "$tmp" "$file"; then
        return 0
    fi
    cat "$tmp" >"$file"
}
