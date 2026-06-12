#!/usr/bin/env bash
set -euo pipefail

CONFIG="${HOME}/.ssh/config"
[ -r "$CONFIG" ] || { echo "no readable $CONFIG"; sleep 2; exit 1; }

host=$(awk '
/^[[:space:]]*[Hh]ost[[:space:]]/ && $2 !~ /[*?!]/ { print $2 }
' "$CONFIG" | sort -u | fzf \
    --prompt="ssh >> " --reverse --height=100% \
    --preview='ssh -G {} 2>/dev/null | awk "/^(user|hostname|port|identityfile|proxyjump|proxycommand) /" | sort' \
    --preview-window='right:50%:wrap') || exit 0


[ -z "$host" ] && exit 0

session="ssh-${host//./_}"
session="${session//:/_}"

if ! tmux has-session -t "=$session" 2>/dev/null; then
    tmux new-session -d -s "$session" "ssh $host"
fi
tmux switch-client -t "$session"

