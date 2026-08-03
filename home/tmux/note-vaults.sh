#!/usr/bin/env bash
# note-vaults.sh — shared definition of the note vaults searched by the tmux
# note-finder scripts. Sourced by tmux-note-finder.sh and tmux-note-name-finder.sh
#
# note_existing_roots() filters the list down to whatever actually
# exists on the current machine, so this one file works everywhere.

# Paths may contain spaces but each entry should be double-quoted.
VAULTS=(
  "${HOME}/pj_notes"
  "${HOME}/work_notes"
)

# Echo one absolute path per line for every vault that exists on this machine.
note_existing_roots() {
  local v
  for v in "${VAULTS[@]}"; do
    [ -d "$v" ] && printf '%s\n' "$v"
  done
}
