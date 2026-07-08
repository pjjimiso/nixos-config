#!/usr/bin/env bash
# tmux-note-name-finder.sh — regex-search file/dir NAMES across every note vault
# and open the chosen match. Searches each vault in VAULTS that exists on this
# machine (see note-vaults.sh).
set -euo pipefail

# shellcheck source=/dev/null
source "${HOME}/.local/bin/note-vaults.sh"

if ! command -v fd  >/dev/null; then echo "fd not on PATH";      sleep 2; exit 1; fi
if ! command -v fzf >/dev/null; then echo "fzf not on PATH";     sleep 2; exit 1; fi

mapfile -t roots < <(note_existing_roots)
[ ${#roots[@]} -eq 0 ] && { echo "no note vaults found on this machine"; sleep 2; exit 1; }

# Reload on every keystroke with the query treated as an fd regex ({q}).
# `|| true` keeps fzf alive while the regex is mid-typing and momentarily invalid.
FD='fd --hidden --exclude .git --color=never'

# The reload bind is a raw shell string, so the roots must be pre-quoted here or
# a path with spaces (e.g. "OneDrive - Intel") would split into several args.
roots_q=""
for r in "${roots[@]}"; do
  roots_q+=" $(printf '%q' "$r")"
done

# bat previews files; for directories fall back to a tree/ls listing.
if command -v bat >/dev/null; then
  PREVIEW='if [ -d {} ]; then ls -la -- {}; else bat --color=always --style=numbers -- {}; fi'
else
  PREVIEW='if [ -d {} ]; then ls -la -- {}; else head -n 200 -- {}; fi'
fi

# Passing absolute roots makes fd emit absolute paths, so a match already tells
# us which vault it came from.
selection=$(
  $FD . "${roots[@]}" \
    | fzf --disabled \
          --prompt 'notes (regex) > ' \
          --bind "change:reload:$FD --regex {q}$roots_q || true" \
          --preview "$PREVIEW" \
          --preview-window 'right:60%:wrap'
) || exit 0

[ -z "$selection" ] && exit 0

target="$selection"   # already absolute

if [ -d "$target" ]; then
  # Open a new window rooted in the directory (tmux -c handles the path, spaces
  # and all), with nvim's file browser there.
  exec tmux new-window -c "$target" "nvim ."
else
  exec tmux new-window -c "$(dirname "$target")" "nvim -- '${target}'"
fi
