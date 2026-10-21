#!/bin/zsh
# ./build.sh          -> build/Horizon.app
# ./build.sh install  -> additionally copy to /Applications and launch
set -e
cd "$(dirname "$0")"

APP=build/Horizon.app

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

swift build -c release
rm -rf $APP
mkdir -p $APP/Contents/MacOS $APP/Contents/Resources
cp .build/release/Horizon $APP/Contents/MacOS/
cp Resources/Info.plist $APP/Contents/
cp Resources/AppIcon.icns $APP/Contents/Resources/
codesign --force --sign - $APP
echo "Gebaut: $APP"

if [[ "$1" == "install" ]]; then
    pkill -x Horizon || true
    rm -rf /Applications/Horizon.app
    cp -R $APP /Applications/
    open /Applications/Horizon.app
    echo "Installiert und gestartet: /Applications/Horizon.app"
fi
