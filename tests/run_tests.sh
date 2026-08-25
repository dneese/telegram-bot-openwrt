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
for F in esc alog html_prep balance_tags utf8fix jesc devices_kb mask_secrets uci_autocommit brk_file brk_ok brk_set is_mut skill_pick sanitize_cmd model_list unglue_cmd fast_intent kb_pick kb_fetch learn_note cmd_banned key_slot qmatch t mk_markups mact_set mact_get wf_safe ok_port ok_ip trim_out semi_split; do
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
for F in esc alog html_prep balance_tags utf8fix jesc devices_kb mask_secrets uci_autocommit brk_file brk_ok brk_set is_mut skill_pick sanitize_cmd model_list unglue_cmd fast_intent kb_pick kb_fetch learn_note cmd_banned key_slot qmatch t mk_markups mact_set mact_get wf_safe ok_port ok_ip trim_out semi_split; do
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

# --- cmd_banned (жорсткі бани ai_run; wget|head тепер ДОЗВОЛЕНИЙ — шаблон KB-феча) ---
if cmd_banned "rm -rf /tmp/x"; then ok "ban: rm -rf ловиться"; else bad "ban: rm -rf" "-"; fi
if cmd_banned "uci show x | sh"; then ok "ban: пайп на sh ловиться"; else bad "ban: |sh" "-"; fi
if cmd_banned "wget -qO- https://raw.githubusercontent.com/x/kb/warp.md | head -c 3400"; then bad "ban: wget|head НЕ має банитись (KB-феч)" "+"; else ok "ban: wget|head дозволений"; fi
if cmd_banned "curl -s https://x.y | grep z"; then bad "ban: curl|grep НЕ має банитись" "+"; else ok "ban: curl|grep дозволений"; fi

# --- kb_pick zaborona/vk ---
eq "kb: vk заблокований → zaborona" "$(kb_pick 'vk.com заблокований в україні, відкрий доступ')" "zaborona"
# --- sanitize: 2>&1 легальний (хибний бан ламав діагностику на живому логу) ---
if sanitize_cmd 'curl -sI https://vk.com 2>&1 | head -1'; then ok "san: 2>&1 дозволений"; else bad "san: 2>&1" "-"; fi
if sanitize_cmd 'reboot 2>&1 &'; then bad "san: справжній фон-& ловиться" "+"; else ok "san: справжній фон-& ловиться"; fi
# --- cmd_banned: інцидент 24.08 — flush таблиць файрвола ЗАВЖДИ заборонений ---
if cmd_banned "nft flush table inet fw4"; then ok "ban: nft flush table ловиться"; else bad "ban: nft flush" "-"; fi
if cmd_banned "iptables -F && reboot"; then ok "ban: iptables -F ловиться"; else bad "ban: iptables -F" "-"; fi
if cmd_banned "nft list ruleset | head -20"; then bad "ban: nft list НЕ має банитись" "+"; else ok "ban: nft list дозволений"; fi
if cmd_banned "conntrack -F"; then bad "ban: conntrack -F (безпечний метод) НЕ має банитись" "+"; else ok "ban: conntrack -F дозволений"; fi
# --- key_slot (маршрут ключів за префіксом; та сама логіка в install.sh і /key) ---
eq "keyslot: gsk_ → ai_key" "$(key_slot 'gsk_AbC12345678901234567890')" "ai_key"
eq "keyslot: sk-or-v1 → ai_key2" "$(key_slot 'sk-or-v1-abcdef0123456789abcdef')" "ai_key2"
eq "keyslot: інший → ai_key3" "$(key_slot 'AQ.Xyz1234567890123456789')" "ai_key3"
if key_slot '' 2>/dev/null; then bad "keyslot: пустий відхилено" "+"; else ok "keyslot: пустий відхилено"; fi

# --- mk_markups (розширене меню: розділи + підменю) ---
T_btn_status_uk='📊 Статус'; T_btn_dev_uk='📱 Пристрої'; T_btn_wifi_uk='📶 Wi-Fi'
T_btn_fw_uk='🛡 Фаєрвол'; T_btn_dg_uk='🔧 Діагностика'; T_btn_sys_uk='⚙️ Система'
T_btn_watch_uk='👀 Слідкування'; T_btn_alias_uk='🏷 Імена'; T_btn_ai_uk='🤖 AI-чат'
T_btn_help_uk='❓ Довідка'; T_rbyes_uk='✅ Так'; T_rbno_uk='❌ Скасувати'
T_aic1_uk='✅ Виконати'; T_aic2_uk='🔒 Зі страховкою'; T_aic0_uk='❌ Скасовано'
T_aioff_uk='⛔️ Вийти'; T_mnback_uk='⬅️ Меню'; T_btn_qr_uk='🔑 QR Wi-Fi'
T_btn_scan_uk='📡 Wi-Fi скан'; T_btn_wan_uk='🌐 Інтернет'; T_btn_bk_uk='💾 Бекап'
T_btn_rb_uk='⚡️ Перезавантаження'; T_rbky_uk='✅ Так, відкотити!'
mk_markups
has "menu: головне містить розділ wifi" "$MENU_MARKUP" 'mnu:wifi'
has "menu: головне містить розділ sys" "$MENU_MARKUP" 'mnu:sys'
has "menu: головне містить fw і dg" "$MENU_MARKUP" 'mnu:fw'
has "menu: головне містить dg" "$MENU_MARKUP" 'mnu:dg'
if command -v jsonfilter >/dev/null 2>&1; then
  for MK in MENU_MARKUP WIFI_MARKUP FW_MARKUP DG_MARKUP SYS_MARKUP RBK_CONF_MARKUP; do
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

# --- qmatch нові нуль-токенові теми ---
eq "qm: температура CPU" "$(qmatch 'яка температура процесора?')" "q_temp"
eq "qm: вільна RAM" "$(qmatch 'скільки ram вільно?')" "q_res"
eq "qm: публічний IP" "$(qmatch 'який у мене публічний ip?')" "q_pubip"
if qmatch 'зроби проброс порту' >/dev/null; then bad "qm: зміни не матчяться в quick" "+"; else ok "qm: зміни не матчяться в quick"; fi

# --- sanitize: ; всередині лапок = літерал (лог 25.08: sed 's/a;b/' ламав діагностику) ---
if sanitize_cmd "cat /proc/net/dev | sed 's/.*: //;s/,/ /g' | head -5"; then ok "san: ; у sed-лапках дозволений"; else bad "san: ; у sed-лапках" "-"; fi
if sanitize_cmd 'echo a;b'; then bad "san: сирого ; ланцюга нема" "+"; else ok "san: сирий ; відхилено"; fi
if sanitize_cmd 'echo "x$(id)"'; then bad "san: \$() у подвійних лапках відхилено" "+"; else ok "san: \$() у лапках відхилено (виконується!)"; fi

# --- semi_split: легаси ";-ланцюжки" -> батч читання ---
eq "ssplit: 3 частини" "$(semi_split 'apk list | grep wg; ls /etc/x 2>/dev/null; ubus call a status' | wc -l | tr -d ' ')" "3"
eq "ssplit: лапки захищають ;" "$(semi_split "sed 's/a;b/' file" | wc -l | tr -d ' ')" "1"
eq "ssplit: подвійні лапки" "$(semi_split 'echo "x;y" f' | wc -l | tr -d ' ')" "1"
has "ssplit: частини цілі" "$(semi_split 'a1;b2;c3' | sed -n 2p)" 'b2'

# --- fast_intent: трафік/прошивка без AI ---
eq "fint: хто качає більше всіх" "$(fast_intent 'Кто качает сейчас больше всех?')" "devices"
eq "fint: яка прошивка" "$(fast_intent 'Какая прошивка?')" "sys_info"
eq "fint: як встановити бота" "$(fast_intent 'Как такого бота установить?')" "help"

printf -- '---\nPASS=%d FAIL=%d\n' "$PASS" "$FAIL"
# --- qmatch (нуль-токеновий шар uci) ---
eq "qm: пароль wifi" "$(qmatch 'який пароль від wifi?')" "wifi_pass"
eq "qm: Пароль мереж" "$(qmatch 'Пароль мережі який?')" "wifi_pass"
eq "qm: dns сервери" "$(qmatch 'які dns сервери стоять?')" "dns_cfg"
eq "qm: юзери" "$(qmatch 'хто такі користувачі системи?')" "users"
if qmatch 'налаштуй wireguard' >/dev/null; then bad "qm: складне не матчиться" "+"; else ok "qm: складне не матчиться"; fi
if qmatch 'погода київ' >/dev/null; then bad "qm: погода не матчиться" "+"; else ok "qm: погода не матчиться"; fi
printf -- '---\nPASS=%d FAIL=%d\n' "$PASS" "$FAIL"
rm -rf "$DIR" 2>/dev/null
[ "$FAIL" = 0 ]
