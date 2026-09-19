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

# Resolve a symlink chain to its ultimate target (follows relative links,
# canonicalizes .. via cd). Prints empty and fails on unresolvable chains.
resolve_symlink_chain() {
    local p="$1" target seen=0
    while [[ -L "$p" ]]; do
        (( seen++ < 40 )) || return 1
        target="$(readlink "$p")"
        case "$target" in
            /*) p="$target" ;;
            *) p="$(dirname "$p")/$target" ;;
        esac
    done
    [[ -n "$p" ]] || return 1
    ( cd "$(dirname "$p")" 2>/dev/null && printf '%s/%s\n' "$PWD" "$(basename "$p")" )
}

# Header line of the legacy hand-added ~/.functions sourcing loop. The
# remover below deletes from this line through its closing fi.
LEGACY_FUNCTIONS_LOOP_BEGIN="# zsh functions folder"

# Remove the legacy ~/.functions sourcing loop (header through its closing
# fi) from a zsh startup file. Only a block opened by the known header is
# ever touched: header-less lookalikes are left alone (conservative beats
# destructive — a global substring absorb could strip lines out of an
# unrecognized compound command and leave bare done/fi behind). The closing
# fi may carry surrounding whitespace; an unclosed header aborts with
# nonzero status and the file is left untouched. Commits go through a
# same-directory temp + mv with mode preservation, mirroring zsh-profile's
# atomic writer — never a truncating redirect into the live file.
remove_legacy_functions_loop() {
    local file="$1" dir tmp mode
    [[ -f "$file" ]] || return 0
    dir="$(dirname "$file")"
    tmp="$(mktemp "$dir/.zsh-functions.XXXXXX")"
    if ! awk -v begin="$LEGACY_FUNCTIONS_LOOP_BEGIN" '
        $0 == begin { skipping = 1; found = 1; next }
        skipping && $0 ~ /^[ \t]*fi[ \t]*$/ { skipping = 0; next }
        !skipping { print }
        END { if (!found) exit 0; exit skipping }
    ' "$file" >"$tmp"; then
        rm -f "$tmp"
        echo "Error: legacy functions loop in $file has no closing fi — refusing to migrate" >&2
        return 1
    fi
    if cmp -s "$tmp" "$file"; then
        rm -f "$tmp"
        return 0
    fi
    mode="$(stat -f %Lp "$file" 2>/dev/null || stat -c %a "$file" 2>/dev/null)" || {
        rm -f "$tmp"
        echo "Error: cannot read mode of $file" >&2
        return 1
    }
    chmod "$mode" "$tmp" && mv -f "$tmp" "$file"
}
