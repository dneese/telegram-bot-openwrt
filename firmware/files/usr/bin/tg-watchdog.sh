#!/bin/sh
# tg-watchdog.sh — watchdog для WARP + PBR + бота
# Запускати через cron: */2 * * * * /usr/bin/tg-watchdog.sh
# Або: crontab -e → */2 * * * * /usr/bin/tg-watchdog.sh

LOG="/tmp/tg-watchdog.log"
TGDIR="/etc/tg-bot"
BOT="/usr/bin/tg-bot.sh"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG"; }
# Обмежуємо лог — тримаємо останні100 рядків
tail -100 "$LOG" 2>/dev/null > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"

# === 1. Бот ===
if ! pgrep -f tg-bot.sh >/dev/null 2>&1; then
  log "RESTART: tg-bot.sh not running"
  nohup "$BOT" &>/dev/null &
  sleep 2
  if pgrep -f tg-bot.sh >/dev/null 2>&1; then
    log "OK: tg-bot.sh started"
  else
    log "FAIL: tg-bot.sh failed to start"
  fi
fi

# === 2. WARP ===
WARP_OK=0
# Перевіряємо чи є інтерфейс warp і чи він UP
if ip link show warp 2>/dev/null | grep -q "UP"; then
  # Перевіряємо чи працює тунель — пінг через warp
  if ping -c 1 -W 3 -I warp 1.1.1.1 >/dev/null 2>&1; then
    WARP_OK=1
  fi
fi

if [ "$WARP_OK" -eq 0 ]; then
  log "RESTART: WARP is down"
  # Перезапускаємо WARP
  if [ -x /etc/init.d/warp ]; then
    /etc/init.d/warp restart >/dev/null 2>&1
  elif command -v wg-quick >/dev/null 2>&1; then
    wg-quick down warp 2>/dev/null
    sleep 2
    wg-quick up warp 2>/dev/null
  fi
  sleep 3
  # Перевіряємо після перезапуску
  if ip link show warp 2>/dev/null | grep -q "UP"; then
    log "OK: WARP restarted"
  else
    log "FAIL: WARP restart failed"
  fi
fi

# === 3. PBR (nftables + ip rule) ===
BFILE="$TGDIR/blocked.list"
if [ -f "$BFILE" ] && [ -s "$BFILE" ]; then
  # Перевіряємо чи є ip rule для mark 0x1
  if ! ip rule show | grep -q "fwmark 0x1"; then
    log "RESTART: PBR ip rule missing"
    ip rule add fwmark 0x1 lookup 100 2>/dev/null
    ip route replace default dev warp table 100 2>/dev/null
  fi
  # Перевіряємо чи є nft set
  if ! nft list set inet fw4 blocked_net >/dev/null 2>&1; then
    log "RESTART: PBR nft set missing, reapplying"
    nft add set inet fw4 blocked_net '{ type ipv4_addr; flags interval; }' 2>/dev/null
    while IFS= read -r CIDR; do
      [ -n "$CIDR" ] && nft add element inet fw4 blocked_net "{ $CIDR }" 2>/dev/null
    done < "$BFILE"
    nft insert rule inet fw4 prerouting ip daddr @blocked_net meta mark set 0x1 2>/dev/null
  fi
fi

# === 4. Мережа ===
# Перевіряємо чи є дефолтний маршрут
if ! ip route show default | grep -q "default"; then
  log "RESTART: no default route, restarting network"
  /etc/init.d/network restart >/dev/null 2>&1
  sleep 5
  log "OK: network restarted"
fi
