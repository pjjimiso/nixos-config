#!/usr/bin/env bash
# tmux-note-finder.sh - live-greps the contents of every note vault and opens
# the chosen file in a new tmux window at the matched line. Searches each vault
# in VAULTS that exists on this machine (see note-vaults.sh).
set -euo pipefail

# shellcheck source=/dev/null
source "${HOME}/.local/bin/note-vaults.sh"

RG_PREFIX='rg --column --line-number --no-heading --color=always --smart-case'

if ! command -v rg >/dev/null;  then echo "ripgrep not on PATH"; sleep 2; exit 1; fi
if ! command -v fzf >/dev/null; then echo "fzf not on PATH";     sleep 2; exit 1; fi

mapfile -t roots < <(note_existing_roots)
[ ${#roots[@]} -eq 0 ] && { echo "no note vaults found on this machine"; sleep 2; exit 1; }

# bat if available (highlights the matched line); otherwise plain `head`.
if command -v bat >/dev/null; then
PREVIEW='bat --color=always --style=numbers --highlight-line {2} -- {1}'
else
PREVIEW='head -n 200 -- {1}'
fi

# Pass the vault roots as absolute arguments so rg emits absolute paths: matches
# can come from either vault, so a single base dir can no longer reconstruct them.
selection=$(
rg --no-heading --line-number --color=never '.' "${roots[@]}" \
  | fzf --delimiter ':' \
        --prompt 'notes > ' \
        --preview "$PREVIEW" \
        --preview-window 'right:60%:+{2}/2'
) || exit 0

[ -z "$selection" ] && exit 0

file=$(printf '%s' "$selection" | cut -d: -f1)
line=$(printf '%s' "$selection" | cut -d: -f2)

# Open in a new tmux window rooted at the file's directory; nvim '+N' jumps to line N.
exec tmux new-window -c "$(dirname "$file")" "nvim '+${line}' -- '${file}'"
