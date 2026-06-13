#!/usr/bin/env bash
# pj-notes-finder.sh - live-greps ~/pj_notes contents and open the chosen
# file in a new tmux window at the matched line.
set -euo pipefail

NOTES_DIR="${HOME}/pj_notes"
RG_PREFIX='rg --column --line-number --no-heading --color=always --smart-case'

if ! command -v rg >/dev/null;  then echo "ripgrep not on PATH"; sleep 2; exit 1; fi
if ! command -v fzf >/dev/null; then echo "fzf not on PATH";     sleep 2; exit 1; fi

cd "$NOTES_DIR"

# bat if available (highlights the matched line); otherwise plain `head`.
if command -v bat >/dev/null; then
PREVIEW='bat --color=always --style=numbers --highlight-line {2} -- {1}'
else
PREVIEW='head -n 200 {1}'
fi

selection=$(
rg --no-heading --line-number --color=never '.' . \
  | fzf --delimiter ':' \
        --prompt 'pj_notes > ' \
        --preview "$PREVIEW" \
        --preview-window 'right:60%:+{2}/2'
) || exit 0

[ -z "$selection" ] && exit 0

file=$(printf '%s' "$selection" | cut -d: -f1)
line=$(printf '%s' "$selection" | cut -d: -f2)

# Open in a new tmux window in NOTES_DIR; nvim '+N' jumps to line N.
exec tmux new-window -c "$NOTES_DIR" "nvim '+${line}' -- '${file}'"
