#!/bin/sh
# ============================================================
#  tg-watch.sh — live-push подій роутера в Telegram
#  Джерело ідеї: alexwbaule/telegramopenwrt (lanports watcher).
#
#  Події:
#   • нова DHCP-аренда (dnsmasq DHCPACK)
#   • link up/down фізичних портів і WLAN (крім lo)
#
#  Конфіг: uci tgbot.config (token/chatid читаються щоразу — hot-config)
#   watch_quiet=1  → тихий режим: події пишуться в лог, але не надсилаються
#
#  Антишум: дедуп тієї самої події 10 хв (.wl_<hash>) + глобальний
#  rate-limit 30 с (.wl_rl); застарілі маркери чистяться щогодини.
#
#  Офлайн-тест парсера: sh tests/run_tests.sh tg-bot.sh tg-watch.sh
# ============================================================

DIR=/etc/tg-bot
RL=30      # rate-limit між повідомленнями, с
DEDUP=600  # вікно дедупу однакової події, с

watch_match() {
  # $1 = рядок logread -> stdout "dhcp <ip> <mac>" | "link <if> <up|down>" | "" (не наша подія)
  case "$1" in
    *"DHCPACK"*)
      L=$(printf '%s' "$1" | sed -n 's/.*DHCPACK on \([0-9.]*\) to \([0-9a-fA-F:]*\).*/\1 \2/p')
      [ -z "$L" ] && L=$(printf '%s' "$1" | sed -n 's/.*DHCPACK([^)]*) \([0-9.]*\) \([0-9a-fA-F:]*\).*/\1 \2/p')
      [ -n "$L" ] && { echo "dhcp $L"; return; }
      ;;
    *"link becomes ready"*)
      IF=$(printf ' %s' "$1" | sed -n 's/.*[ :]\([a-zA-Z0-9.@-]*\): link becomes ready.*/\1/p')
      [ -n "$IF" ] && [ "$IF" != "lo" ] && { echo "link $IF up"; return; }
      ;;
    *" link up"*|*" link down"*)
      IF=$(printf ' %s' "$1" | sed -n 's/.*[ :]\([a-zA-Z0-9.@-]*\): link up.*/\1/p')
      ST="up"
      [ -z "$IF" ] && { IF=$(printf ' %s' "$1" | sed -n 's/.*[ :]\([a-zA-Z0-9.@-]*\): link down.*/\1/p'); ST="down"; }
      [ -n "$IF" ] && [ "$IF" != "lo" ] && { echo "link $IF $ST"; return; }
      ;;
  esac
  echo ""
}

jesc_lite() {
  # мінімальний JSON-ескейп для власних текстів (імʼя з aliases може містити лапки)
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n\t' '  '
}

mac_name() {
  # $1=MAC -> імʼя пристрою: dhcp.leases(MAC->IP) -> aliases(IP|Name)
  MIP=$(awk -v m="$(printf '%s' "$1" | tr 'A-Z' 'a-z')" 'tolower($2)==m{print $3; exit}' /tmp/dhcp.leases 2>/dev/null)
  [ -n "$MIP" ] && grep -m1 "^$MIP|" "$DIR/aliases" 2>/dev/null | cut -d'|' -f2
}

send_ev() {
  # $1=текст (без HTML) -> sendMessage; конфіг читаємо щоразу
  WTT=$(uci -q get tgbot.config.token)
  WCCH=$(uci -q get tgbot.config.chatid)
  [ -z "$WTT" ] || [ -z "$WCCH" ] && return
  curl -s --max-time 15 -H "Content-Type: application/json" \
    -d "{\"chat_id\":\"$WCCH\",\"text\":\"$(jesc_lite "$1")\"}" \
    "https://api.telegram.org/bot$WTT/sendMessage" >/dev/null 2>&1
}

mkdir -p "$DIR"

# Single-instance guard: пайп-діти переживають procd stop → накопичувались дублі,
# кожен інстанс пушив ту саму подію. Живий pidfile = вихід; trap прибирає дітей при завершенні.
WPIDF="$DIR/.watch_pid"
if [ -s "$WPIDF" ] && kill -0 "$(cat "$WPIDF" 2>/dev/null)" 2>/dev/null; then
  logger -t tg-watch "already running (pid $(cat "$WPIDF")) — exit"
  exit 0
fi
echo $$ > "$WPIDF"
trap 'rm -f "$WPIDF"; kill $(jobs -p) 2>/dev/null' EXIT TERM INT

logread -f 2>/dev/null | while IFS= read -r LINE; do
  EV=$(watch_match "$LINE")
  [ -n "$EV" ] || continue
  [ "$(uci -q get tgbot.config.watch_quiet)" = "1" ] && continue
  set -- $EV
  KIND=$1; A=$2; B=$3
  case "$KIND" in
    dhcp)
      WKEY="d|$A|$B"
      NM=$(mac_name "$B"); NS=""
      [ -n "$NM" ] && NS=" [$NM]"
      WTXT="🔌 Нова DHCP-аренда: $A → ${B}$NS"
      ;;
    link)
      WKEY="l|$A|$B"
      WTXT="🌐 Порт $A: $B"
      ;;
    *) continue ;;
  esac
  WSF="$DIR/.wl_$(printf '%s' "$WKEY" | md5sum | cut -c1-8)"
  WNOW=$(date +%s)
  WOLD=$(cat "$WSF" 2>/dev/null)
  [ -n "$WOLD" ] && [ $(( WNOW - WOLD )) -lt $DEDUP ] && continue
  WRLT=$(cat "$DIR/.wl_rl" 2>/dev/null)
  [ -n "$WRLT" ] && [ $(( WNOW - WRLT )) -lt $RL ] && continue
  echo "$WNOW" > "$WSF"
  echo "$WNOW" > "$DIR/.wl_rl"
  find "$DIR" -name '.wl_*' ! -name '.wl_rl' ! -name "$(basename "$WSF")" -mmin +60 -exec rm -f {} \; 2>/dev/null
  logger -t tg-watch "push: $WTXT"
  send_ev "$WTXT"
done
