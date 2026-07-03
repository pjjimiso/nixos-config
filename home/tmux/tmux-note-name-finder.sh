#!/usr/bin/env bash
# tmux-note-name-finder.sh — regex-search names of files and directories
# in notes dir and open the chosen match.
set -euo pipefail

NOTES_DIR="${HOME}/pj_notes"

if ! command -v fd  >/dev/null; then echo "fd not on PATH";      sleep 2; exit 1; fi
if ! command -v fzf >/dev/null; then echo "fzf not on PATH";     sleep 2; exit 1; fi

cd "$NOTES_DIR"

# Reload on every keystroke with the query treated as an fd regex ({q})
# `|| true` keeps fzf alive while the regex is mid-typing and momentarily invalid.
FD='fd --hidden --exclude .git --color=never'

# bat previews files; for directories fall back to a tree/ls listing.
if command -v bat >/dev/null; then
  PREVIEW='if [ -d {} ]; then ls -la -- {}; else bat --color=always --style=numbers -- {}; fi'
else
  PREVIEW='if [ -d {} ]; then ls -la -- {}; else head -n 200 -- {}; fi'
fi

selection=$(
  $FD . \
    | fzf --disabled \
          --prompt 'pj_notes (regex) > ' \
          --bind "change:reload:$FD --regex {q} || true" \
          --preview "$PREVIEW" \
          --preview-window 'right:60%:wrap'
) || exit 0

[ -z "$selection" ] && exit 0

target="${NOTES_DIR}/${selection}"

if [ -d "$target" ]; then
  # Open a new window rooted in the directory, with nvim's file browser there.
  exec tmux new-window -c "$target" "nvim '+cd ${target}' ."
else
  exec tmux new-window -c "$NOTES_DIR" "nvim -- '${target}'"
fi
