#!/usr/bin/env bash
# daily-note.sh — Open today's daily note in nvim inside a dedicated tmux session,
# creating today's note from the shared template if it doesn't already exist.
#
# The note body comes from ONE template file that Obsidian's Daily Notes plugin
# also points at ($VAULT_DIR/_templates/daily.md). Because it lives inside the
# vault it syncs to the phone, so a note created here and a note created by
# tapping "today's daily note" in Obsidian start from identical content.
#
# This script is environment-agnostic: it assumes only that it is running in a
# terminal with nvim + tmux on PATH.
set -euo pipefail

NOTES_DIR="${PJ_NOTES_DIR:-$HOME/pj_notes/2_Areas/_Daily-Notes}"
VAULT_DIR="${PJ_VAULT_DIR:-$HOME/pj_notes}"
TEMPLATE_FILE="${PJ_DAILY_TEMPLATE:-$VAULT_DIR/_templates/daily.md}"

# Launch mode:
#   attach  (default) — this invocation owns a terminal (ghostty on Legion, or
#                       the Windows Terminal fallback) -> attach the session here.
#   switch            — this invocation has no terminal of its own (the hidden
#                       WSL hotkey call) -> redirect the already-attached client.
mode="${1:-attach}"

# Which day's note to open: today (default), yesterday, tomorrow, or anything
# else GNU `date -d` understands (e.g. "-2 days", "2026-12-25"). Keeping the
# relative-date logic here means every launcher (Legion dconf, the WSL Ctrl+. /
# Ctrl+, / Ctrl+/ hotkeys) shares one definition of "yesterday".
day="${2:-today}"

target="$(date -d "$day" +%F)"            # e.g. 2026-06-13
note_path="${NOTES_DIR}/${target}.md"

# Session will share the same name as the daily note
SESSION="${DAILY_NOTE_SESSION:-daily-${target}}"

mkdir -p "$NOTES_DIR"

# Renders the shared daily-note template file that Obsidian uses, so a note
# created here or in Obsidian are identical.
render_template() {
  cat -- "$TEMPLATE_FILE"
}

# Built-in fallback, used only if the template file is missing (e.g. before the
# vault has synced to this machine). Mirrors the original hardcoded format.
default_template() {
  cat <<'EOF'
## Focus Item
- [ ]

## Tasks
- [ ]
- [ ]
- [ ]

## Scratch


EOF
}

# Create the note if it doesn't already exist
if [ ! -f "$note_path" ]; then
  if [ -f "$TEMPLATE_FILE" ]; then
    render_template "$day" > "$note_path"
  else
    default_template > "$note_path"
  fi
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
