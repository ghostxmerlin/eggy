#!/bin/zsh
set -eu
cd -- "${0:A:h}"
ENGINE="$PWD/.tools/Godot.app/Contents/MacOS/Godot"
"$ENGINE" --headless --editor --path "$PWD" --import --quit
"$ENGINE" --headless --path "$PWD" --export-pack macOS "$PWD/dist/CloudClub.app/Contents/Resources/game.pck"
/usr/bin/codesign --force --deep --sign - "$PWD/dist/CloudClub.app"
