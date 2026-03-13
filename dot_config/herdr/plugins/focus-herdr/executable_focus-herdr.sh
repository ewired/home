#!/usr/bin/env bash
set -u

CELLULOID_MPRIS_PREFIX="org.mpris.MediaPlayer2.io.github.celluloid_player.Celluloid"

echo "$HERDR_PLUGIN_EVENT_JSON" >> /tmp/herdrlog.txt

agent_status=$(printf '%s' "${HERDR_PLUGIN_EVENT_JSON:-}" | jq -r '.data.agent_status // empty')
pane_id=$(printf '%s' "${HERDR_PLUGIN_EVENT_JSON:-}" | jq -r '.data.pane_id // empty')
[ -n "$pane_id" ] || exit 0

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/herdr-focus"
mkdir -p "$STATE_DIR" 2>/dev/null
safe_pane_id=$(printf '%s' "$pane_id" | tr -c 'A-Za-z0-9._-' '_')
STATE_FILE="$STATE_DIR/$safe_pane_id.status"
prev_status=$(cat "$STATE_FILE" 2>/dev/null || true)
printf '%s' "$agent_status" > "$STATE_FILE"

case "$agent_status" in idle|done|blocked) ;; *) exit 0 ;; esac
[ "$prev_status" = "working" ] || exit 0

names=$(gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus --method org.freedesktop.DBus.ListNames 2>/dev/null)
bus_name=$(printf '%s' "$names" | grep -oE "'[^']+'" | tr -d "'" | grep -F "$CELLULOID_MPRIS_PREFIX" | head -n1)
if [ -n "$bus_name" ]; then
  gdbus call --session --dest "$bus_name" --object-path /org/mpris/MediaPlayer2 --method org.mpris.MediaPlayer2.Player.Pause >/dev/null 2>&1
fi

herdr terminal title clear

win_id=$(dbus-send --session --print-reply=literal --dest=org.gnome.Shell /org/gnome/Shell/Extensions/Windows org.gnome.Shell.Extensions.Windows.List 2>/dev/null | jq -r '.[] | select(.wm_class == "foot" and ((.title // "") | ascii_downcase | contains("herdr"))) | .id' 2>/dev/null | head -n1)
if [ -n "$win_id" ]; then
  gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell/Extensions/Windows --method org.gnome.Shell.Extensions.Windows.Activate "$win_id" >/dev/null 2>&1
fi

herdr agent focus "$pane_id" >/dev/null 2>&1
exit 0
