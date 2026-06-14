#!/usr/bin/env bash
# tmux-daily-finder.sh — pick from the Daily Notes (newest first, so today is
# at the top) and open the chosen note in its own tmux session.
#
# Sibling to tmux-note-finder.sh, but instead of grepping all of ~/pj_notes it
# just lists the _Daily-Notes directory. It reuses the same `daily-<date>`
# session naming as daily-note.sh, so a note opened here shares the session the
# Ctrl+. hotkey would use for that day.
set -euo pipefail

NOTES_DIR="${PJ_NOTES_DIR:-$HOME/pj_notes/2_Areas/_Daily-Notes}"
VAULT_DIR="${PJ_VAULT_DIR:-$HOME/pj_notes}"

command -v fzf >/dev/null || { echo "fzf not on PATH"; sleep 2; exit 1; }
cd "$NOTES_DIR" 2>/dev/null || { echo "missing $NOTES_DIR"; sleep 2; exit 1; }

# bat gives nice markdown rendering if present; otherwise a plain cat preview.
if command -v bat >/dev/null; then
  PREVIEW='bat --color=always --style=plain --language=markdown -- {}'
else
  PREVIEW='cat -- {}'
fi

# Daily-note filenames are YYYY-MM-DD.md, so a reverse lexical sort is also a
# reverse chronological sort: today's note (the largest date) lands first.
selection=$(
  ls -1 *.md 2>/dev/null | sort -r \
    | fzf --prompt 'daily-note > ' \
          --preview "$PREVIEW" \
          --preview-window 'right:60%:wrap'
) || exit 0
[ -z "$selection" ] && exit 0

note_path="${NOTES_DIR}/${selection}"
stem="${selection%.md}"
SESSION="daily-${stem}"

nvim_cmd="nvim '+cd ${VAULT_DIR}' -- '${note_path}'"

# Create the session detached if needed, then surface it. This script is run
# from a tmux popup, so $TMUX is set and we redirect the current client.
if ! tmux has-session -t "=${SESSION}" 2>/dev/null; then
  tmux new-session -d -s "$SESSION" -c "$NOTES_DIR" "$nvim_cmd"
fi

if [ -n "${TMUX:-}" ]; then
  exec tmux switch-client -t "=${SESSION}"
else
  exec tmux attach-session -t "=${SESSION}"
fi
