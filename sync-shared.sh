#!/bin/sh
# Дзеркалить репозиторій у спільне сховище Android (/storage/emulated/0)
# Викликається автоматично git-хуком post-commit, або вручну: ./sync-shared.sh
SRC="$HOME/Documents/tg-router-bot"
DST="/storage/emulated/0/Documents/tg-router-bot"
[ -d "$SRC" ] || { echo "нема $SRC"; exit 1; }
mkdir -p "$DST" 2>/dev/null

if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete --exclude '.git/' "$SRC/" "$DST/"
else
  # fallback без rsync: копіювання файлів по одному (+ видалення зайвих)
  find "$SRC" -type f ! -path '*/.git/*' | while read -r F; do
    R="${F#"$SRC"/}"
    mkdir -p "$DST/$(dirname "$R")" 2>/dev/null
    cp "$F" "$DST/$R"
  done
  cd "$DST" 2>/dev/null && find . -type f | while read -r F; do
    [ -f "$SRC/${F#./}" ] || rm -f "$F"
  done
fi
echo "synced -> $DST ($(date '+%H:%M:%S'))"
