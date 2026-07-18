#!/bin/sh
# Build the binary and assemble dist/Markable.app
set -e
cd "$(dirname "$0")"

swift build -c release

rm -rf dist
mkdir -p dist/Markable.app/Contents/MacOS dist/Markable.app/Contents/Resources
cp .build/release/Markable dist/Markable.app/Contents/MacOS/
cp -R .build/release/Markable_Markable.bundle dist/Markable.app/Contents/Resources/
cp Info.plist dist/Markable.app/Contents/
[ -f AppIcon.icns ] && cp AppIcon.icns dist/Markable.app/Contents/Resources/

codesign --force --deep -s - dist/Markable.app
echo "Built dist/Markable.app"
