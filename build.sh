#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="SuiviEleves"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

# Compilation. Certaines Command Line Tools récentes (SDK 27, sans Xcode) n'exposent
# pas le plugin de macros SwiftUI : `@State` ne compile plus ("plugin for module
# 'SwiftUIMacros' not found"). On retombe alors sur un SDK précédent, s'il existe.
build_release() {
	swift build -c release
}

echo "→ Compilation du binaire release..."
if ! build_release; then
	echo "→ Échec avec le SDK par défaut, tentative avec un SDK de repli..." >&2
	default_sdk="$(xcrun --show-sdk-path 2>/dev/null || true)"
	if [ -n "$default_sdk" ]; then
		default_sdk="$(cd "$default_sdk" && pwd -P)"
	fi
	ok=""
	for sdk in /Library/Developer/CommandLineTools/SDKs/MacOSX*.sdk; do
		[ -d "$sdk" ] || continue
		resolu="$(cd "$sdk" && pwd -P)"
		[ "$resolu" = "$default_sdk" ] && continue
		echo "   essai avec $sdk"
		if SDKROOT="$sdk" build_release; then
			ok="$sdk"
			break
		fi
	done
	if [ -z "$ok" ]; then
		echo "✗ Build impossible : installe Xcode, ou un SDK macOS compatible." >&2
		exit 1
	fi
	echo "   ✓ build réussi avec $ok" >&2
fi

echo "→ Nettoyage de l'ancien bundle..."
rm -rf "$APP_BUNDLE"

echo "→ Assemblage du bundle .app..."
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp Resources/Info.plist "$CONTENTS/Info.plist"

echo "→ Signature ad-hoc..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo
echo "✓ $APP_BUNDLE construit"
echo "  Lancer :     open $APP_BUNDLE"
echo "  Installer :  mv $APP_BUNDLE /Applications/  &&  open /Applications/$APP_BUNDLE"
