#!/bin/zsh
cd -- "${0:A:h}"
ENGINE="$PWD/.tools/Godot.app/Contents/MacOS/Godot"
if [[ ! -x "$ENGINE" ]]; then
  ENGINE="$(command -v godot)"
fi
if [[ ! -x "$ENGINE" ]]; then
  echo "请安装 Godot 4.7 或更新版本，然后打开 project.godot。"
  exit 1
fi
exec "$ENGINE" --path "$PWD" "$@"
