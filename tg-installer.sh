#!/bin/sh
# ============================================================
#  tg-router-bot — remote installer (bootstrap), one-liner.
#  Джерело ідеї: utakamo/oasis (oasis_installer.sh).
#
#  Одна команда на чистому роутері:
#    wget -O - https://raw.githubusercontent.com/dneese/telegram-bot-openwrt/master/tg-installer.sh | sh
#
#  З опціями (аргументи після `sh -s --`):
#    wget -O - .../tg-installer.sh | sh -s -- --token '123:ABC' --chatid 111 --lang uk
#
#  Скрипт тягне всі файли з GitHub у /tmp, перевіряє синтаксис
#  і запускає install.sh (той самий, що й для ручної установки).
# ============================================================

REPO="dneese/telegram-bot-openwrt"
BR="master"
RAW="https://raw.githubusercontent.com/$REPO/$BR"
TMP="/tmp/tgrb.$$"

say() { printf '%s\n' "$*"; }
die() { say "❌ $*"; rm -rf "$TMP" 2>/dev/null; exit 1; }

fetch() { # $1=relpath -> stdout; uclient-fetch (рідний OpenWrt, з TLS) -> curl -> wget
  if command -v uclient-fetch >/dev/null 2>&1; then
    uclient-fetch -qO- "$RAW/$1" 2>/dev/null
  elif command -v curl >/dev/null 2>&1; then
    curl -fsSL --max-time 60 "$RAW/$1" 2>/dev/null
  elif command -v wget >/dev/null 2>&1; then
    wget -q -T 60 -O - "$RAW/$1" 2>/dev/null
  else
    die "У системі немає ні uclient-fetch, ні curl, ні wget"
  fi || die "Не вдалося завантажити $1. Перевірте дату/час (date) та SSL: /etc/init.d/sysntpd restart"
}

FILES="tg-bot.sh tg-analyze.sh tg-watch.sh tg-doctor.sh tg-bot.init tg-watch.init tg-doctor.hotplug install.sh \
tgbot.menu.json tgbot.acl.json tgbot.settings.js \
prompts/core.txt prompts/recipes.txt prompts/facts.md prompts/intent.txt \
prompts/learned/lessons.md \
prompts/skills/wifi.md prompts/skills/vpn.md prompts/skills/dns.md prompts/skills/firewall.md \
prompts/skills/services.md prompts/skills/network-dhcp.md prompts/skills/system-misc.md"

mkdir -p "$TMP/prompts/skills" "$TMP/prompts/learned" || die "Немає доступу до /tmp"

say "⬇️  Завантажую tg-router-bot ($REPO@$BR)..."
for F in $FILES; do
  fetch "$F" > "$TMP/$F"
  [ -s "$TMP/$F" ] || die "Порожня відповідь для $F"
done

sh -n "$TMP/tg-bot.sh" 2>/dev/null   || die "tg-bot.sh не проходить синтаксис — качаю знову пізніше"
sh -n "$TMP/install.sh" 2>/dev/null  || die "install.sh не проходить синтаксис"

say "📦 Отримано $(echo $FILES | wc -w) файлів. Запуск install.sh ${*:+$*}..."
sh "$TMP/install.sh" "$@"
RC=$?
[ "$RC" = "0" ] && rm -rf "$TMP" 2>/dev/null || say "⚠️ install.sh повернув код $RC (файли лишлись у $TMP)"
exit $RC
