#!/bin/sh
# Baut Hoofy 3D für das Steam Deck (Linux x86_64) nach export/steamdeck/.
# Beim ersten Mal werden Godots Export-Vorlagen geladen (~1 GB, einmalig).
#   tools/deck_export.sh
#   DECK=deck@steamdeck.local tools/deck_export.sh   # danach per SSH aufs Deck kopieren
cd "$(dirname "$0")/.." || exit 1
GODOT=${GODOT:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}
VERSION=$("$GODOT" --version | sed -E 's/^([0-9.]+)\.stable.*/\1/')
VORLAGEN="$HOME/Library/Application Support/Godot/export_templates/$VERSION.stable"
if [ ! -f "$VORLAGEN/linux_release.x86_64" ]; then
	echo "Lade Export-Vorlagen für Godot $VERSION …"
	TMP=$(mktemp -d)
	curl -L --fail -o "$TMP/vorlagen.tpz" \
		"https://github.com/godotengine/godot/releases/download/$VERSION-stable/Godot_v$VERSION-stable_export_templates.tpz" || exit 1
	unzip -q "$TMP/vorlagen.tpz" -d "$TMP" && mkdir -p "$VORLAGEN" && cp "$TMP"/templates/* "$VORLAGEN"/ && rm -rf "$TMP"
fi
[ -d assets/download ] || python3 tools/assets.py
mkdir -p export/steamdeck
"$GODOT" --headless --path . --import >/dev/null 2>&1
"$GODOT" --headless --path . --export-release "Steam Deck" export/steamdeck/hoofy3d.x86_64 || exit 1
ls -lh export/steamdeck
if [ -n "$DECK" ]; then
	ssh "$DECK" mkdir -p Games/hoofy3d && scp export/steamdeck/* "$DECK":Games/hoofy3d/ && echo "Auf dem Deck: ~/Games/hoofy3d/hoofy3d.x86_64"
fi
