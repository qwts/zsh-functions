# Function template

Copy this skeleton for `functions/<name>`. Lines starting with `#` are guidance;
delete them in the real file.

```zsh
# functions/<name>: one-line purpose.
# Usage: <name> <args>
emulate -L zsh
setopt pipefail

<name>() {
  emulate -L zsh
  local arg1="${1:?usage: <name> <args>}"
  # Quote expansions. Declare locals. No `export PATH` here.
  # For PATH/fpath work, call the catalog helpers instead of inline logic.
}

# Private helpers go in the same file, prefixed with _.
_<name>_helper() {
  emulate -L zsh
  # ...
}
```
