#!/bin/sh
# /etc/rc.local.d/tgbot.sh — автозапуск бота + PBR при завантаженні
# Додається в /etc/rc.local

# Чекаємо поки мережа піднімається
sleep 10

TGDIR="/etc/tg-bot"
BOT="/usr/bin/tg-bot.sh"
LOG="/tmp/tg-watchdog.log"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') BOOT: $1" >> "$LOG"; }

# Запускаємо бота
if [ -x "$BOT" ] && ! pgrep -f tg-bot.sh >/dev/null 2>&1; then
  nohup "$BOT" &>/dev/null &
  sleep 2
  pgrep -f tg-bot.sh >/dev/null 2>&1 && log "tg-bot started" || log "tg-bot FAILED"
fi

# Застосовуємо PBR якщо є blocked.list
BFILE="$TGDIR/blocked.list"
if [ -f "$BFILE" ] && [ -s "$BFILE" ]; then
  nft add set inet fw4 blocked_net '{ type ipv4_addr; flags interval; }' 2>/dev/null
  nft flush set inet fw4 blocked_net 2>/dev/null
  while IFS= read -r CIDR; do
    [ -n "$CIDR" ] && nft add element inet fw4 blocked_net "{ $CIDR }" 2>/dev/null
  done < "$BFILE"
  nft insert rule inet fw4 prerouting ip daddr @blocked_net meta mark set 0x1 2>/dev/null
  ip rule del fwmark 0x1 2>/dev/null
  ip rule add fwmark 0x1 lookup 100
  ip route replace default dev warp table 100 2>/dev/null
  log "PBR applied ($(wc -l < "$BFILE") entries)"
fi
