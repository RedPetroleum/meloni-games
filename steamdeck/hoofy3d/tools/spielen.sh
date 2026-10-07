#!/bin/sh
# Startet Hoofy 3D am Mac im Fenster.
#   tools/spielen.sh           volle Grafik
#   tools/spielen.sh --deck    leichtere Grafik wie auf dem Steam Deck (bei Rucklern)
GODOT=${GODOT:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}
cd "$(dirname "$0")/.." || exit 1
exec "$GODOT" --path . -- "$@"
