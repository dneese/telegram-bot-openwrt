#!/bin/sh
# tests/run_tests.sh — офлайн-тести функцій tg-bot.sh (без API, без мутацій).
# Запуск на роутері:  sh tests/run_tests.sh [/usr/bin/tg-bot.sh]
# Запуск у Termux:    sh tests/run_tests.sh ~/Documents/tg-router-bot/tg-bot.sh
SRC="$1"
[ -f "$SRC" ] || { echo "usage: run_tests.sh <path/to/tg-bot.sh>"; exit 2; }
TD=${TMPDIR:-/tmp}; [ -d "$TD" ] || TD=$HOME
DIR=$(mktemp -d "$TD/tgt.XXXXXX" 2>/dev/null) || { DIR="$TD/tgt.$$"; mkdir -p "$DIR"; }
export DIR
BOT_LANG=uk
T_d_name_ru='Устр'; T_d_name_uk='Пристр'; T_d_name_en='Dev'
PASS=0; FAIL=0

xf() { # витяг функцію з SRC (стилі: name(){ та name() {)
  awk -v fn="$1" '
    !p && index($0, fn"(")==1 && substr($0, length(fn)+3) ~ /^[[:space:]]*\{/ { p=1 }
    p { print }
    p && $0=="}" { exit }
  ' "$SRC"
}
MISS=""
for F in esc alog html_prep balance_tags utf8fix jesc devices_kb mask_secrets uci_autocommit brk_file brk_ok brk_set is_mut t; do
  xf "$F" > "$DIR/.xf" || true
  [ -s "$DIR/.xf" ] && cat "$DIR/.xf" >> "$DIR/fns" || MISS="$MISS $F"
done
rm -f "$DIR/.xf"
[ -z "$MISS" ] || { echo "EXTRACT FAIL:$MISS"; exit 2; }
. "$DIR/fns"; rm -f "$DIR/fns"
for F in esc alog html_prep balance_tags utf8fix jesc devices_kb mask_secrets uci_autocommit brk_file brk_ok brk_set is_mut t; do
  type "$F" >/dev/null 2>&1 || { echo "LOAD FAIL: $F"; exit 2; }
done

ok()   { PASS=$((PASS+1)); printf 'ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf 'FAIL %s\n      got: %s\n' "$1" "$(printf '%s' "$2" | head -c 200)"; }
eq()   { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want: $3)" "$2"; fi; }
has()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (must contain: $3)" "$2" ;; esac; }
nohas(){ case "$2" in *"$3"*) bad "$1 (must NOT contain: $3)" "$2" ;; *) ok "$1" ;; esac; }

# --- esc ---
eq "esc: &<> ескейпляться" "$(esc 'a<b&c')" 'a&lt;b&amp;c'

# --- html_prep: білий список ---
eq "html_prep: strong→b" "$(html_prep '<strong>hi</strong>')" '<b>hi</b>'
has "html_prep: script лишається екранованим" "$(html_prep '<script>x</script>')" '&lt;script&gt;'
eq  "html_prep: https-посилання розкривається" "$(html_prep '<a href="https://x.y">L</a>')" '<a href="https://x.y">L</a>'
# html_prep: javascript: href лишається екранованим (balance_tags прибере сирітський </a>)
has "html_prep: javascript: href НЕ розкривається" "$(html_prep '<a href="javascript:x">L</a>')" '&lt;a href='
eq  "html_prep: blockquote expandable" "$(html_prep '<blockquote expandable>b</blockquote>')" '<blockquote expandable>b</blockquote>'

# --- balance_tags ---
eq "btag: незакритий <b>" "$(balance_tags '<b>bold')" '<b>bold</b>'
eq "btag: зайвий закриваючий викидається" "$(balance_tags 'a</i>b')" 'ab'
eq "btag: вкладеність b>i" "$(balance_tags '<b><i>x')" '<b><i>x</i></b>'
# перехрестя: невідповідний closer дропається, текст лишається у відкритих тегах
eq "btag: перехрестя </b> при <b><i>" "$(balance_tags '<b><i>x</b>y')" '<b><i>xy</i></b>'
# strong — нативний тег Telegram, лишається як є
eq "btag: strong проходить без змін" "$(balance_tags '<strong>x</strong>')" '<strong>x</strong>'
# сирітський </a> після не-білого <a> (кейс javascript:-посилання) чиститься
nohas "btag: сирітський </a> видаляється" "$(balance_tags "$(html_prep '<a href="javascript:x">L</a>')")" '</a>'

# --- utf8fix (приймає АРГУМЕНТ, не stdin) ---
eq "utf8fix: кирилиця+емодзі не ламаються" "$(utf8fix 'привіт 😀ок')" 'привіт 😀ок'
eq "utf8fix: контрольний \\001 видаляється" "$(utf8fix "$(printf 'a\001b')")" 'ab'
eq "utf8fix: сирітський continuation-байт" "$(utf8fix "$(printf 'а\320')")" 'а'

# --- jesc (приймає АРГУМЕНТ) ---
JOUT=$(jesc "$(printf 'a"b\\c\nd\te')")
eq "jesc: лапки/backslash/newline/tab" "$JOUT" 'a\"b\\c\nd e'
if command -v jsonfilter >/dev/null 2>&1; then
  JR=$(printf '{"c":"%s"}' "$(jesc "$(printf 'ряд "1"\nрядок2 \\ слеш 😀')")" | jsonfilter -e '$.c' 2>/dev/null)
  eq "jesc: roundtrip jsonfilter (multiline+quotes)" "$JR" "$(printf 'ряд "1"\nрядок2 \\ слеш 😀')"
else
  echo "skip jesc roundtrip: немає jsonfilter"
fi

# --- mask_secrets ---
MS=$(mask_secrets 'api_key=abcdef123456 password=secret private_key=AAAABBBBCCCCDDDD')
nohas "mask: key замасковано" "$MS" 'abcdef123456'
nohas "mask: password замасковано" "$MS" 'secret'
has  "mask: маркер ••• присутній" "$MS" '••••••'

# --- uci_autocommit ---
UA=$(uci_autocommit "uci set network.lan.ipaddr='192.168.1.2'")
has "acomm: додає commit network" "$UA" '&& uci commit network'
UAn=$(uci_autocommit "uci set dhcp.lan.leasetime='12h' && uci commit dhcp")
nohas "acomm: без дубля commit" "$UAn" 'commit dhcp && uci commit dhcp'
eq  "acomm: не-uci рядок недоторканий" "$(uci_autocommit 'cat /etc/hosts')" 'cat /etc/hosts'
UA2=$(uci_autocommit "uci set wireless.@wifi-iface[0].ssid='X'")
has "acomm: commit wireless" "$UA2" '&& uci commit wireless'

# --- circuit breaker ---
brk_set testm 60
if brk_ok testm; then bad "brk: свіжий breaker блокує" "allowed"; else ok "brk: свіжий breaker блокує"; fi
echo $(( $(date +%s) - 5 )) > "$(brk_file testm)"
if brk_ok testm; then ok "brk: прострочений пропускає"; else bad "brk: прострочений пропускає" "blocked"; fi
rm -f "$(brk_file testm)"

# --- is_mut ---
if is_mut "uci set network.wan.proto='pppoe'"; then ok "is_mut: uci set = мутація"; else bad "is_mut: uci set = мутація" "-"; fi
if is_mut "uci get network.wan.proto"; then bad "is_mut: get = читання" "+"; else ok "is_mut: get = читання"; fi
if is_mut "apk add nlbwmon"; then ok "is_mut: apk add = мутація"; else bad "is_mut: apk add = мутація" "-"; fi
if is_mut "apk info nlbwmon"; then bad "is_mut: apk info = читання" "+"; else ok "is_mut: apk info = читання"; fi
if is_mut "reboot"; then ok "is_mut: reboot = мутація"; else bad "is_mut: reboot = мутація" "-"; fi

# --- devices_kb (живі дані роутера, лише читання) ---
KB=$(devices_kb)
if [ -n "$KB" ]; then
  ROWS=$(printf '%s' "$KB" | jsonfilter -e '$.inline_keyboard[@]' 2>/dev/null | grep -c '^' )
  ROWS=$(printf '%s' "$KB" | jsonfilter -e '$.inline_keyboard' 2>/dev/null | wc -l)
  if [ "${ROWS:-0}" -ge 1 ] 2>/dev/null; then ok "devices_kb: JSON валідний, рядків=$ROWS"; else bad "devices_kb: JSON валідний" "$KB"; fi
  CB=$(printf '%s' "$KB" | jsonfilter -e '$.inline_keyboard[0][0].callback_data' 2>/dev/null)
  case "$CB" in st:*"|"*) ok "devices_cb: формат st:MAC|IP ($CB)" ;; *) bad "devices_cb: формат st:MAC|IP" "$CB" ;; esac
  L=${#CB}
  if [ "$L" -le 64 ]; then ok "devices_cb: довжина ≤64 ($L)"; else bad "devices_cb: довжина ≤64" "$CB"; fi
  TX=$(printf '%s' "$KB" | jsonfilter -e '$.inline_keyboard[0][0].text' 2>/dev/null)
  has "devices_kb: підпис містить · .остактет" "$TX" '· .'
else
  echo "skip devices_kb: немає онлайн-хостів зараз"
fi

printf -- '---\nPASS=%d FAIL=%d\n' "$PASS" "$FAIL"
rm -rf "$DIR" 2>/dev/null
[ "$FAIL" = 0 ]
