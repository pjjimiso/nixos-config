#!/usr/bin/env bash
set -euo pipefail

CONFIG="${HOME}/.ssh/config"
[ -r "$CONFIG" ] || { echo "no readable $CONFIG"; sleep 2; exit 1; }

# Emit one "host  hostname" line per concrete Host block so fzf can match on
# either column (e.g. typing a HostName fragment like ch4prod finds the alias).
# Wildcard/negated Host patterns are skipped, and HostName lines under them are
# not attached to the previous real host.
host=$(awk '
/^[[:space:]]*[Hh]ost[[:space:]]/ {
    if (h != "") print h "\t" hn
    h = ""; hn = ""
    if ($2 !~ /[*?!]/) h = $2
    next
}
/^[[:space:]]*[Hh]ost[Nn]ame[[:space:]]/ && h != "" { hn = $2 }
END { if (h != "") print h "\t" hn }
' "$CONFIG" | sort -u | awk -F'\t' '{ printf "%-28s %s\n", $1, $2 }' | fzf \
    --prompt="ssh >> " --reverse --height=100% \
    --nth=1,2 \
    --preview='ssh -G {1} 2>/dev/null | awk "/^(user|hostname|port|identityfile|proxyjump|proxycommand) /" | sort' \
    --preview-window='right:50%:wrap' | awk '{ print $1 }') || exit 0


[ -z "$host" ] && exit 0

session="ssh-${host//./_}"
session="${session//:/_}"

if ! tmux has-session -t "=$session" 2>/dev/null; then
    tmux new-session -d -s "$session" "ssh $host"
fi
tmux switch-client -t "$session"
