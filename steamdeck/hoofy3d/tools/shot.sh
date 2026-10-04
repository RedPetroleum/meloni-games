#!/bin/sh
# Startet Hoofy 3D mit Testlauf-Optionen, bricht nach $ZEITLIMIT Sekunden ab (Skriptfehler
# beenden Godot nicht) und meldet Fehler mit Status 1.
#   tools/shot.sh --shots=120 --zeit=17 --input="10-300:vor+antreiben"
#   HEADLESS=1 tools/shot.sh --frames=600      # ohne Fenster, nur Logik
cd "$(dirname "$0")/.." || exit 1
GODOT=${GODOT:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}
ZEITLIMIT=${ZEITLIMIT:-90}
LOG=../../build/hoofy3d/lauf.log
mkdir -p ../../build/hoofy3d
# Neue Skripte/Klassen und Assets bekannt machen (sonst "Identifier not declared")
"$GODOT" --headless --path . --import >/dev/null 2>&1
FLAGS="--path ."
[ -n "$HEADLESS" ] && FLAGS="--headless $FLAGS"
"$GODOT" $FLAGS -- "$@" >"$LOG" 2>&1 &
PID=$!
( sleep "$ZEITLIMIT"; kill "$PID" 2>/dev/null && echo "Zeitlimit $ZEITLIMIT s erreicht" >>"$LOG" ) &
WAECHTER=$!
wait "$PID"
kill "$WAECHTER" 2>/dev/null
grep -E "Gelände|Bewuchs|Testlauf|Screenshot|Zeitlimit|ERROR|WARNING|SCRIPT|  at:" "$LOG" | grep -v "leaked\|resources still in use\|PagedAllocator\|ObjectDB" | head -40
! grep -qE "SCRIPT ERROR|Zeitlimit|Parse Error" "$LOG"
