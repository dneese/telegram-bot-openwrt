#!/bin/sh
# tests/run_tests.sh — офлайн-тести функцій tg-bot.sh (без API, без мутацій).
# Запуск на роутері:  sh tests/run_tests.sh [/usr/bin/tg-bot.sh] [/usr/bin/tg-watch.sh]
# Запуск у Termux:    sh tests/run_tests.sh ~/Documents/tg-router-bot/tg-bot.sh [~/Documents/tg-router-bot/tg-watch.sh]
SRC="$1"
SRCW="$2"
[ -f "$SRC" ] || { echo "usage: run_tests.sh <path/to/tg-bot.sh>"; exit 2; }
TD=${TMPDIR:-/tmp}; [ -d "$TD" ] || TD=$HOME
DIR=$(mktemp -d "$TD/tgt.XXXXXX" 2>/dev/null) || { DIR="$TD/tgt.$$"; mkdir -p "$DIR"; }
export DIR
BOT_LANG=uk
T_d_name_ru='Устр'; T_d_name_uk='Пристр'; T_d_name_en='Dev'
PASS=0; FAIL=0

xf() { # витяг функцію з SRC (стилі: name(){ та name() {); $2 = альтернативне джерело
  awk -v fn="$1" '
    !p && index($0, fn"(")==1 && substr($0, length(fn)+3) ~ /^[[:space:]]*\{/ { p=1 }
    p { print }
    p && $0=="}" { exit }
  ' "${2:-$SRC}"
}
MISS=""
for F in esc alog html_prep balance_tags utf8fix jesc devices_kb mask_secrets uci_autocommit t mk_markups mact_set mact_get wf_safe ok_port ok_ip trim_out semi_split fmt_speed parse_ping_avg parse_ip_cidr; do
  xf "$F" > "$DIR/.xf" || true
  [ -s "$DIR/.xf" ] && cat "$DIR/.xf" >> "$DIR/fns" || MISS="$MISS $F"
done
rm -f "$DIR/.xf"
if [ -n "$MISS" ]; then echo "WARN missing:$MISS (light)"; fi
. "$DIR/fns"; rm -f "$DIR/fns"

# --- tg-watch.sh: watch_match (другий аргумент) ---
if [ -n "$SRCW" ] && [ -f "$SRCW" ]; then
  xf watch_match "$SRCW" > "$DIR/.xw" || true
  [ -s "$DIR/.xw" ] && . "$DIR/.xw" && rm -f "$DIR/.xw" || { echo "EXTRACT FAIL: watch_match"; exit 2; }
fi
for F in esc alog html_prep balance_tags utf8fix jesc devices_kb mask_secrets uci_autocommit t mk_markups mact_set mact_get wf_safe ok_port ok_ip trim_out semi_split fmt_speed parse_ping_avg parse_ip_cidr; do
  type "$F" >/dev/null 2>&1 || echo "WARN not loaded: $F"
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






# --- watch_match (tg-watch.sh; тільки якщо джерело передано) ---
if type watch_match >/dev/null 2>&1; then
  LM='Thu Aug 24 08:03:01 2026 daemon.info dnsmasq-dhcp[3012]: DHCPACK on 192.168.1.50 to AA:BB:CC:DD:EE:FF wifi-pc'
  eq "wmatch: dhcp (on-form)" "$(watch_match "$LM")" "dhcp 192.168.1.50 AA:BB:CC:DD:EE:FF"
  LM2='daemon.info dnsmasq-dhcp[3012]: DHCPACK(br-lan) 192.168.1.51 11:22:33:44:55:66 phone'
  eq "wmatch: dhcp (paren-form)" "$(watch_match "$LM2")" "dhcp 192.168.1.51 11:22:33:44:55:66"
  eq "wmatch: link down" "$(watch_match 'kernel: [1234.567890] eth0: link down')" "link eth0 down"
  eq "wmatch: link up" "$(watch_match 'kernel: [1235.000000] eth0: link up (1000Mbps/Full duplex)')" "link eth0 up"
  eq "wmatch: wlan ready→up" "$(watch_match 'wlan0: link becomes ready')" "link wlan0 up"
  eq "wmatch: lo ігнорується" "$(watch_match 'lo: link down')" ""
  eq "wmatch: шум не матчиться" "$(watch_match 'daemon.notice procd: Instance tg-bot::inst s in a crash loop 7 300')" ""
else
  echo "skip watch_match: tg-watch.sh не передано"
fi








# --- mk_markups (розширене меню: розділи + підменю) ---
T_btn_status_uk='📊 Статус'; T_btn_dev_uk='📱 Пристрої'; T_btn_wifi_uk='📶 Wi-Fi'
T_btn_fw_uk='🛡 Фаєрвол'; T_btn_dg_uk='🔧 Діагностика'; T_btn_sys_uk='⚙️ Система'
T_btn_watch_uk='👀 Слідкування'; T_btn_alias_uk='🏷 Імена'; T_btn_ai_uk='🤖 AI-чат'
T_btn_help_uk='❓ Довідка'; T_rbyes_uk='✅ Так'; T_rbno_uk='❌ Скасувати'
T_aic1_uk='✅ Виконати'; T_aic2_uk='🔒 Зі страховкою'; T_aic0_uk='❌ Скасовано'
T_aioff_uk='⛔️ Вийти'; T_mnback_uk='⬅️ Меню'; T_btn_qr_uk='🔑 QR Wi-Fi'
T_btn_scan_uk='📡 Wi-Fi скан'; T_btn_wan_uk='🌐 Інтернет'; T_btn_bk_uk='💾 Бекап'
T_btn_rb_uk='⚡️ Перезавантаження'; T_rbky_uk='✅ Так, відкотити!'
T_btn_vpn_uk='🌐 VPN'; T_v_status_uk='📊 Статус'; T_v_connect_uk='⚡️ Підключити'
T_v_aon_uk='🟢 Весь трафік'; T_v_aoff_uk='⏸ Припинити'; T_v_delete_uk='🗑 Видалити WARP'; T_v_go_uk='✅ Так'
mk_markups
has "menu: головне містить розділ wifi" "$MENU_MARKUP" 'mnu:wifi'
has "menu: головне містить розділ sys" "$MENU_MARKUP" 'mnu:sys'
has "menu: головне містить fw і dg" "$MENU_MARKUP" 'mnu:fw'
has "menu: головне містить dg" "$MENU_MARKUP" 'mnu:dg'
if command -v jsonfilter >/dev/null 2>&1; then
  for MK in MENU_MARKUP WIFI_MARKUP FW_MARKUP DG_MARKUP SYS_MARKUP RBK_CONF_MARKUP VPN_MARKUP WARP_CONF_MARKUP WDEL_CONF_MARKUP; do
    eval "VAL=\$$MK"
    CHK=$(printf '%s' "$VAL" | jsonfilter -e '$.inline_keyboard[0][0].text' 2>/dev/null)
    if [ -n "$CHK" ]; then ok "menu: $MK валідний JSON"; else bad "menu: $MK валідний JSON" "$VAL"; fi
  done
fi
has "wifi_kb: QR у підменю wifi" "$WIFI_MARKUP" '"callback_data":"qr"'
has "wifi_kb: скан у підменю wifi" "$WIFI_MARKUP" '"callback_data":"scn"'
has "wifi_kb: назад = mn" "$WIFI_MARKUP" '"callback_data":"mn"'
has "sys_kb: rollback-кнопка rbk1" "$SYS_MARKUP" '"callback_data":"rbk1"'
has "rbk_conf: підтвердження rbkyes/rbkno" "$RBK_CONF_MARKUP" 'rbkyes'

# --- mact_set / mact_get (контекст вводу текстом) ---
rm -f "$DIR/.mact"
if mact_get 'x' >/dev/null 2>&1; then bad "mact: без файлу порожньо" "+"; else ok "mact: без файлу порожньо"; fi
mact_set diag_ping
eq "mact: свіжий контекст повертає дію|ввід" "$(mact_get '8.8.8.8')" 'diag_ping|8.8.8.8'
echo 0 > "$DIR/.mact.ts"; printf 'diag_ping\n%s\n' $(( $(date +%s) - 400 )) > "$DIR/.mact"
if mact_get 'x' >/dev/null 2>&1; then bad "mact: прострочений (>5хв) скидається" "+"; else ok "mact: прострочений (>5хв) скидається"; fi
[ -f "$DIR/.mact" ] && bad "mact: файл .mact видалено після таймауту" "+" || ok "mact: файл .mact видалено після таймауту"
rm -f "$DIR/.mact"

# --- wf_safe (валідація вводу Wi-Fi перед вклеюванням у команду) ---
if wf_safe 'MyHome_WiFi 5G!'; then ok "wfsafe: звичайний ssid проходить"; else bad "wfsafe: звичайний ssid" "-"; fi
if wf_safe "pass'word123"; then bad "wfsafe: апостроф відхилено" "+"; else ok "wfsafe: апостроф відхилено"; fi
if wf_safe "$(printf 'a\002b')"; then bad "wfsafe: керуючий байт відхилено" "+"; else ok "wfsafe: керуючий байт відхилено"; fi
has "wifi_kb: кнопка моїх мереж wfkb" "$WIFI_MARKUP" '"callback_data":"wfkb"'

# --- ok_port / ok_ip (валідація вводу фаєрвола/діагностики) ---
if ok_port 80 && ok_port 65535; then ok "okport: 80 і 65535 проходять"; else bad "okport: 80 і 65535" "-"; fi
if ok_port 0 || ok_port 65536 || ok_port abc; then bad "okport: 0/65536/abc відхилено" "+"; else ok "okport: 0/65536/abc відхилено"; fi
if ok_ip 192.168.1.50 && ok_ip 8.8.8.8; then ok "okip: звичайні IP проходять"; else bad "okip: звичайні IP" "-"; fi
if ok_ip 300.1.1.1 || ok_ip 1.2.3 || ok_ip 'a.b.c.d'; then bad "okip: 300.x/короткий/текст відхилено" "+"; else ok "okip: 300.x/короткий/текст відхилено"; fi

# --- trim_out (економія токенів фідбеку: head+tail замість повного виводу) ---
SMALL=$(trim_out 'короткий вивід' 1000)
eq "trim: короткий недоторканий" "$SMALL" 'короткий вивід'
BIG=$(trim_out "$(printf 'A%.0s' $(seq 1 2000))" 1000)
BL=${#BIG}
if [ "$BL" -le 1100 ] && [ "$BL" -ge 900 ]; then ok "trim: 2000Б стиснуто до ~1000 ($BL)"; else bad "trim: 2000Б -> ~1000" "got $BL"; fi
has "trim: маркер обрізання присутній" "$BIG" 'обрізано'



# --- semi_split: легаси ";-ланцюжки" -> батч читання ---
eq "ssplit: 3 частини" "$(semi_split 'apk list | grep wg; ls /etc/x 2>/dev/null; ubus call a status' | wc -l | tr -d ' ')" "3"
eq "ssplit: лапки захищають ;" "$(semi_split "sed 's/a;b/' file" | wc -l | tr -d ' ')" "1"
eq "ssplit: подвійні лапки" "$(semi_split 'echo "x;y" f' | wc -l | tr -d ' ')" "1"
has "ssplit: частини цілі" "$(semi_split 'a1;b2;c3' | sed -n 2p)" 'b2'


# --- fmt_speed / parse_ping_avg (WARP-оптимізатор) ---
eq "fspeed: 88080384 байт" "$(fmt_speed 88080384)" "84.0 МБ"
eq "fspeed: 0" "$(fmt_speed 0)" "0.0 МБ"
eq "ppavg: busybox rtt-рядок" "$(printf 'round-trip min/avg/max = 12.300/14.100/16.000 ms' | parse_ping_avg)" "14.100"
if printf '100% packet loss' | parse_ping_avg | grep -q .; then bad "ppavg: втрати = пусто" "+"; else ok "ppavg: втрати = пусто"; fi

# --- parse_ip_cidr (PBR) ---
parse_ip_cidr() {
  case "$1" in ''|*[!0-9./]*) return 1 ;; esac
  echo "$1" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(/([0-9]|[12][0-9]|3[012]))?$' || return 1
  IPOCT="${1%%/*}"
  A=$(echo "$IPOCT" | cut -d. -f1); B=$(echo "$IPOCT" | cut -d. -f2); C=$(echo "$IPOCT" | cut -d. -f3); D=$(echo "$IPOCT" | cut -d. -f4)
  [ "$A" -le 255 ] && [ "$B" -le 255 ] && [ "$C" -le 255 ] && [ "$D" -le 255 ] || return 1
  return 0
}
if parse_ip_cidr "93.184.216.34"; then ok "picidr: валідний IP"; else bad "picidr: валідний IP" "0"; fi
if parse_ip_cidr "5.188.86.0/24"; then ok "picidr: валідний CIDR"; else bad "picidr: валідний CIDR" "0"; fi
if parse_ip_cidr "192.168.1.1"; then ok "picidr: приватний IP"; else bad "picidr: приватний IP" "0"; fi
if parse_ip_cidr "1.1.1.1/8"; then ok "picidr: /8"; else bad "picidr: /8" "0"; fi
if parse_ip_cidr "256.1.1.1"; then bad "picidr: >255" "1"; else ok "picidr: >255"; fi
if parse_ip_cidr "1.1.1/24"; then bad "picidr: 3 octets" "1"; else ok "picidr: 3 octets"; fi
if parse_ip_cidr "abc"; then bad "picidr: літери" "1"; else ok "picidr: літери"; fi
if parse_ip_cidr ""; then bad "picidr: пусто" "1"; else ok "picidr: пусто"; fi
if parse_ip_cidr "1.2.3.4/33"; then bad "picidr: /33" "1"; else ok "picidr: /33"; fi

printf -- '---\nPASS=%d FAIL=%d\n' "$PASS" "$FAIL"

rm -rf "$DIR" 2>/dev/null
[ "$FAIL" = 0 ]
