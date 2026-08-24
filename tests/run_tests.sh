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
for F in esc alog html_prep balance_tags utf8fix jesc devices_kb mask_secrets uci_autocommit brk_file brk_ok brk_set is_mut skill_pick sanitize_cmd model_list unglue_cmd fast_intent kb_pick kb_fetch learn_note t; do
  xf "$F" > "$DIR/.xf" || true
  [ -s "$DIR/.xf" ] && cat "$DIR/.xf" >> "$DIR/fns" || MISS="$MISS $F"
done
rm -f "$DIR/.xf"
[ -z "$MISS" ] || { echo "EXTRACT FAIL:$MISS"; exit 2; }
. "$DIR/fns"; rm -f "$DIR/fns"

# --- tg-watch.sh: watch_match (другий аргумент) ---
if [ -n "$SRCW" ] && [ -f "$SRCW" ]; then
  xf watch_match "$SRCW" > "$DIR/.xw" || true
  [ -s "$DIR/.xw" ] && . "$DIR/.xw" && rm -f "$DIR/.xw" || { echo "EXTRACT FAIL: watch_match"; exit 2; }
fi
for F in esc alog html_prep balance_tags utf8fix jesc devices_kb mask_secrets uci_autocommit brk_file brk_ok brk_set is_mut skill_pick sanitize_cmd model_list unglue_cmd fast_intent kb_pick kb_fetch learn_note t; do
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

# --- sanitize_cmd (C5: захист у глибину; пайпи дозволені — скіли їх використовують) ---
if sanitize_cmd "uci set network.lan.ipaddr='192.168.1.2' && uci commit network"; then ok "san: легальний uci set&&commit проходить"; else bad "san: легальний uci set&&commit" "-"; fi
if sanitize_cmd "uci show firewall | head -60"; then ok "san: пайп на head дозволений"; else bad "san: пайп на head" "-"; fi
if sanitize_cmd 'echo `id`'; then bad "san: бектік відхилено" "+"; else ok "san: бектік відхилено"; fi
if sanitize_cmd 'echo $(id)'; then bad "san: \$() відхилено" "+"; else ok "san: \$() відхилено"; fi
if sanitize_cmd 'echo ${PATH}'; then bad "san: \${} відхилено" "+"; else ok "san: \${} відхилено"; fi
if sanitize_cmd 'cat /etc/shadow;reboot'; then bad "san: ; ланцюжок відхилено" "+"; else ok "san: ; ланцюжок відхилено"; fi
if sanitize_cmd 'reboot &'; then bad "san: одиночний & відхилено" "+"; else ok "san: одиночний & відхилено"; fi
ZW=$(printf 'uci set a.b=\342\200\215x')
if sanitize_cmd "$ZW"; then bad "san: zero-width спуф відхилено" "+"; else ok "san: zero-width спуф відхилено"; fi
CTL=$(printf 'a\001b')
if sanitize_cmd "$CTL"; then bad "san: керуючий байт відхилено" "+"; else ok "san: керуючий байт відхилено"; fi

# --- model_list (C6) ---
ML=$(model_list)
eq "model_list: 4 кандидати" "$(printf '%s\n' "$ML" | wc -l | tr -d ' ')" "4"
eq "model_list: перша qwen27b" "$(printf '%s' "$ML" | sed -n 1p)" "qwen/qwen3.6-27b"
has "model_list: є gpt-oss-120b" "$ML" "openai/gpt-oss-120b"

# --- unglue_cmd (хвіст «CMD: -» вклеєний в SAY) ---
eq "unglue: простий хвіст" "$(unglue_cmd 'Що пропінґувати? CMD: -')" "$(printf 'Що пропінґувати?\nCMD: -')"
eq "unglue: теги code" "$(unglue_cmd 'Текст? <code>CMD: -</code>')" "$(printf 'Текст?\nCMD: -')"
eq "unglue: некритий тег" "$(unglue_cmd 'Текст?  <code>CMD: -</code')" "$(printf 'Текст?\nCMD: -')"
eq "unglue: нормальний 2-рядковий недоторканий" "$(unglue_cmd "$(printf 'SAY: все ок\nCMD: -')")" "$(printf 'SAY: все ок\nCMD: -')"
eq "unglue: без хвоста недоторкано" "$(unglue_cmd 'просто текст відповіді')" 'просто текст відповіді'

# --- fast_intent (локальний безкоштовний класифікатор) ---
eq "fint: пристроїв у мережі" "$(fast_intent 'скільки пристроїв у мережі?')" "devices"
eq "fint: хто підключений" "$(fast_intent 'хто підключений до wifi')" "devices"
eq "fint: скан ефіру" "$(fast_intent 'скануй мережу')" "wifi_scan"
eq "fint: сигнал сусідів" "$(fast_intent 'які мережі мають найсильніший сигнал?')" "wifi_scan"
eq "fint: температура" "$(fast_intent 'яка температура CPU?')" ""
eq "fint: аптайм" "$(fast_intent 'покажи аптайм роутера')" "sys_info"
if fast_intent 'зміни DNS на 1.1.1.1' >/dev/null; then bad "fint: DNS не матчиться" "+"; else ok "fint: DNS не матчиться"; fi
if fast_intent 'що таке /mon' >/dev/null; then bad "fint: питання про команду не матчиться" "+"; else ok "fint: питання про команду не матчиться"; fi

# --- skill_pick (keyword→скіл; порядок: wifi,vpn,dns,firewall,services,netdhcp,misc) ---
eq "skill: встанови nlbwmon → services" "$(skill_pick 'встанови nlbwmon')" "$DIR/ai/skills/services.md"
eq "skill: настрой wireguard → vpn" "$(skill_pick 'настрой wireguard')" "$DIR/ai/skills/vpn.md"
eq "skill: Встанови WireGuard → vpn (порядок над services)" "$(skill_pick 'Встанови WireGuard сервер')" "$DIR/ai/skills/vpn.md"
eq "skill: зміни DNS → dns" "$(skill_pick 'зміни DNS на 1.1.1.1')" "$DIR/ai/skills/dns.md"
eq "skill: проброс порту → firewall" "$(skill_pick 'зроби проброс порту 8080')" "$DIR/ai/skills/firewall.md"
eq "skill: гостьова мережа → wifi" "$(skill_pick 'створити гостьову мережу wifi')" "$DIR/ai/skills/wifi.md"
eq "skill: статическая аренда → netdhcp" "$(skill_pick 'сделай статическую аренду для ПК')" "$DIR/ai/skills/network-dhcp.md"
eq "skill: температура CPU → misc" "$(skill_pick 'какая температура CPU?')" "$DIR/ai/skills/system-misc.md"
if skill_pick 'какая погода в Киеве' >/dev/null 2>&1; then bad "skill: погода не матчиться" "matched"; else ok "skill: погода не матчиться"; fi
if skill_pick 'покажи устройства' >/dev/null 2>&1; then bad "skill: девайси не матчаться" "matched"; else ok "skill: девайси не матчаться"; fi

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

# --- kb_pick / kb_fetch (GitHub-база знань) ---
eq "kb: 5ГГц питання → wireless" "$(kb_pick 'чому клієнти 5ГГц відвалюються?')" "wireless"
eq "kb: warp → wireguard" "$(kb_pick 'налаштуй WARP від cloudflare')" "wireguard"
eq "kb: проброс порту → firewall" "$(kb_pick 'зроби проброс порту 8080')" "firewall"
eq "kb: встанови пакет → packages" "$(kb_pick 'встанови nlbwmon для статистики')" "packages"
eq "kb: не працює інтернет → diagnostics" "$(kb_pick 'інтернет пропадає кілька разів на день')" "diagnostics"
if kb_pick 'що таке погода' >/dev/null; then bad "kb: погода не матчиться" "+"; else ok "kb: погода не матчиться"; fi
mkdir -p "$DIR/kbcache"; printf '# тестовий док' > "$DIR/kbcache/wireless.md"
eq "kb_fetch: кеш-хіт" "$(kb_fetch wireless)" '# тестовий док'
eq "kb_fetch: невідома тема = тихо пусто" "$(kb_fetch nosuchtopic123)" ''

# --- learn_note (самонавчання: журнал уроків з обрізанням) ---
rm -f "$DIR/ai/mistakes.md"
learn_note FAIL "uci set bad.option='x' => rc=1 Unknown option"
has "learn: FAIL записано" "$(cat "$DIR/ai/mistakes.md")" "FAIL | uci set bad.option"
for i in 1 2 3; do learn_note OK "спрацювало: рецепт $i"; done
eq "learn: рядків=4" "$(wc -l < "$DIR/ai/mistakes.md" | tr -d ' ')" "4"
rm -f "$DIR/ai/mistakes.md"

printf -- '---\nPASS=%d FAIL=%d\n' "$PASS" "$FAIL"
rm -rf "$DIR" 2>/dev/null
[ "$FAIL" = 0 ]
