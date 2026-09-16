#!/usr/bin/env bash
# Reboot / réinstallation propre.
# À utiliser DÈS qu'une instance est déjà ouverte : ne jamais en empiler une 2e.
# Ferme toutes les instances, reconstruit, réinstalle dans /Applications, relance UNE seule.
set -uo pipefail
cd "$(dirname "$0")"

echo "→ Fermeture de toutes les instances en cours..."
pkill -f "MacOS/SuiviEleves" 2>/dev/null || true
# Attendre leur fin réelle (sinon le garde-fou d'instance unique ferait quitter la nouvelle).
for _ in $(seq 1 50); do
	pgrep -f "MacOS/SuiviEleves" >/dev/null 2>&1 || break
	sleep 0.1
done

echo "→ Build + bundle..."
if ! ./build.sh >/dev/null; then
	echo "✗ Build échoué : réinstallation annulée (l'app en place n'est pas touchée)." >&2
	exit 1
fi

DEST="/Applications/Suivi Élèves.app"
echo "→ Installation dans $DEST ..."
rm -rf "$DEST" 2>/dev/null || true
if ! ditto "SuiviEleves.app" "$DEST" 2>/dev/null; then
	DEST="$HOME/Applications/Suivi Élèves.app"
	mkdir -p "$HOME/Applications"
	rm -rf "$DEST" 2>/dev/null || true
	ditto "SuiviEleves.app" "$DEST"
	echo "  (repli ~/Applications : /Applications non accessible)"
fi
codesign --force --deep --sign - "$DEST" >/dev/null 2>&1 || true

echo "→ Lancement d'une seule instance..."
open "$DEST" --args --show
echo "✓ Suivi Élèves relancé proprement : $DEST"
