#!/bin/sh
# Startet Hoofy headless in einem Szenario aus games/hoofy/game/scenarios.lua.
#
#   tools/hoofy-test.sh selftest                       alle Selbsttests (game/tests/), Status 1 bei Fehler
#   tools/hoofy-test.sh karte_ganz                     Bild nach 1 Frame: build/screens/hoofy-karte_ganz.png
#   tools/hoofy-test.sh leine --input "5-90:RIGHT" --shots 30,60,90
#   SCENARIO_OPTS='only = "katalog"' tools/hoofy-test.sh selftest     weitere Felder im Spielstand
#
# Weitere Argumente gehen an den Runner (--frames, --shots, --input, --seed, --screenshot …).
# Ohne --frames/--shots läuft ein Frame, ohne --seed SEED=1, ohne --screenshot ein Bild nach build/screens/.
set -e
cd "$(dirname "$0")/.."
[ -n "$1" ] || { echo "usage: tools/hoofy-test.sh <szenario> [runner-argumente]"; exit 2; }
scenario=$1; shift
make -s runner sprites >/dev/null
mkdir -p build/screens
save=$(mktemp "${TMPDIR:-/tmp}/hoofy-XXXXXX")
trap 'rm -f "$save"' EXIT
echo "return {scenario = \"$scenario\", ${SCENARIO_OPTS:-}}" > "$save"
frames="--frames 1"; seed="--seed 1"; shot="--screenshot build/screens/hoofy-$scenario.png"
for a in "$@"; do
  case $a in
    --frames|--shots) frames= ;;
    --seed) seed= ;;
    --screenshot) shot= ;;
  esac
done
runner/build/meloni-run --headless $frames $seed $shot --save "$save" "$@" games/hoofy
