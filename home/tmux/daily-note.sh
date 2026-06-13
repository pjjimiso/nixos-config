#!/usr/bin/env bash
# daily-note.sh — create (if needed) and open today's daily note in nvim,
# inside a dedicated per-day tmux session.
#
# This script is environment-agnostic: it assumes only that it is running in a
# terminal with nvim + tmux on PATH. The per-OS hotkey launcher (AutoHotkey on
# the Windows/WSL laptop, a Cinnamon custom shortcut on the legion host) is the
# only thing that differs between machines — both ultimately just run this.
set -euo pipefail

NOTES_DIR="${PJ_NOTES_DIR:-$HOME/pj_notes/2_Areas/_Daily-Notes}"
VAULT_DIR="${PJ_VAULT_DIR:-$HOME/pj_notes}"

# Launch mode:
#   attach  (default) — this invocation owns a terminal (ghostty on Legion, or
#                       the Windows Terminal fallback) -> attach the session here.
#   switch            — this invocation has no terminal of its own (the hidden
#                       WSL hotkey call) -> redirect the already-attached client.
mode="${1:-attach}"

today="$(date +%F)"                       # e.g. 2026-06-13
note_path="${NOTES_DIR}/${today}.md"

# Per-day session name: makes "open today's note" idempotent and survives
# tmux-continuum restoring an older `daily-*` session in the background.
SESSION="${DAILY_NOTE_SESSION:-daily-${today}}"

mkdir -p "$NOTES_DIR"

# Seed the note from the template only the first time it's opened today.
if [ ! -f "$note_path" ]; then
  cat > "$note_path" <<'EOF'
###### Focus
1.

###### Tasks
1.

###### Maintenance
1.
2.
3.

###### Notes

EOF
fi

# Open the note with the vault as cwd so [[wiki-links]] / gf resolve.
# `--` guards against any filename that begins with '-'.
nvim_cmd="nvim '+cd ${VAULT_DIR}' -- '${note_path}'"

# Create the session detached if it doesn't exist yet, then attach to it.
if ! tmux has-session -t "=${SESSION}" 2>/dev/null; then
  tmux new-session -d -s "$SESSION" -c "$NOTES_DIR" "$nvim_cmd"
fi

# Decide how to surface the session:
#   - inside tmux already, or explicit "switch" mode -> redirect the current
#     client (attach would error on nesting / there's no new terminal to fill).
#   - otherwise -> attach in the terminal this invocation owns.
if [ -n "${TMUX:-}" ] || [ "$mode" = "switch" ]; then
  exec tmux switch-client -t "=${SESSION}"
else
  exec tmux attach-session -t "=${SESSION}"
fi
