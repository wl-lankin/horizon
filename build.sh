#!/bin/zsh
# ./build.sh                  -> build/Horizon.app (this Mac's architecture)
# ./build.sh install          -> additionally copy to /Applications and launch
# ./build.sh release X.Y.Z    -> universal app plus dist/ with DMG, update zip and latest.json
#
# Signing: with the Horizon certificate (~/.horizon/signing.keychain-db locally, or SIGN_KEYCHAIN +
# SIGN_KEYCHAIN_PASSWORD in CI). The designated requirement then stays the same across versions, so
# calendar access and the updater's signer check survive updates. Without it the build is ad-hoc signed.
set -e
cd "$(dirname "$0")"

MODE=${1:-build}
VERSION=${2:-$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)}
APP=build/Horizon.app
REPO=wl-lankin/horizon

if [[ ! -f Resources/AppIcon.icns ]]; then
    ICONSET=build/AppIcon.iconset
    mkdir -p $ICONSET
    swift scripts/make_icon.swift build/icon_1024.png
    for s in 16 32 128 256 512; do
        sips -z $s $s build/icon_1024.png --out $ICONSET/icon_${s}x${s}.png >/dev/null
        sips -z $((s*2)) $((s*2)) build/icon_1024.png --out $ICONSET/icon_${s}x${s}@2x.png >/dev/null
    done
    iconutil -c icns $ICONSET -o Resources/AppIcon.icns
fi

ARCHS=()
[[ $MODE == release ]] && ARCHS=(--arch arm64 --arch x86_64)
swift build -c release $ARCHS
BIN=$(swift build -c release $ARCHS --show-bin-path)/Horizon

rm -rf $APP
mkdir -p $APP/Contents/MacOS $APP/Contents/Resources
cp $BIN $APP/Contents/MacOS/Horizon
cp Resources/Info.plist $APP/Contents/
cp Resources/AppIcon.icns $APP/Contents/Resources/
/usr/libexec/PlistBuddy -c "Set CFBundleShortVersionString $VERSION" $APP/Contents/Info.plist
/usr/libexec/PlistBuddy -c "Set CFBundleVersion $VERSION" $APP/Contents/Info.plist

SIGN_KEYCHAIN=${SIGN_KEYCHAIN:-$HOME/.horizon/signing.keychain-db}
if [[ -f $SIGN_KEYCHAIN ]]; then
    PASS=${SIGN_KEYCHAIN_PASSWORD:-$(cat $HOME/.horizon/signing.pass)}
    security unlock-keychain -p "$PASS" $SIGN_KEYCHAIN
    IDENTITY=$(security find-identity -p codesigning $SIGN_KEYCHAIN | awk '/Horizon Code Signing/ {print $2; exit}')
    codesign --force --timestamp=none --keychain $SIGN_KEYCHAIN --sign $IDENTITY $APP
    echo "Signiert mit dem Horizon-Zertifikat"
else
    codesign --force --sign - $APP
    echo "Ad-hoc signiert (kein Horizon-Zertifikat gefunden)"
fi
echo "Gebaut: $APP ($VERSION)"

if [[ $MODE == install ]]; then
    pkill -x Horizon || true
    rm -rf /Applications/Horizon.app
    cp -R $APP /Applications/
    open /Applications/Horizon.app
    echo "Installiert und gestartet: /Applications/Horizon.app"
fi

if [[ $MODE == release ]]; then
    DIST=dist
    rm -rf $DIST build/dmg
    mkdir -p $DIST build/dmg

    ZIP=Horizon-$VERSION.zip
    ditto -c -k --keepParent $APP $DIST/$ZIP

    cp -R $APP build/dmg/
    ln -s /Applications build/dmg/Applications
    hdiutil create -quiet -volname "Horizon $VERSION" -srcfolder build/dmg -fs HFS+ -format UDZO -ov $DIST/Horizon-$VERSION.dmg
    cp $DIST/Horizon-$VERSION.dmg $DIST/Horizon-macOS.dmg

    SIGNATURE=$(swift scripts/sign_update.swift $DIST/$ZIP)
    NOTES=$(.github/release-notes.sh "v$VERSION" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))')
    cat > $DIST/latest.json <<EOF
{
  "version": "$VERSION",
  "url": "https://github.com/$REPO/releases/download/v$VERSION/$ZIP",
  "signature": "$SIGNATURE",
  "notes": $NOTES,
  "minimumSystemVersion": "14.0",
  "pub_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    echo "Release-Dateien in $DIST:"
    ls -1 $DIST
fi
