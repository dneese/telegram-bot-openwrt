#!/bin/sh
# tg-analyze.sh — проактивний аналізатор здоровʼя роутера (cron щогодини)
# Аномалії: brute-force, диск >90%, температура >80°C, вичерпання DHCP-пулу
DIR="/etc/tg-bot"
export PATH="/usr/sbin:/usr/bin:/sbin:/bin"
T=$(uci -q get tgbot.config.token)
C=$(uci -q get tgbot.config.chatid)
[ -z "$T" ] || [ -z "$C" ] && exit 0

send_alert() {
  curl -s --max-time 10 -H "Content-Type: application/json" \
    -d "{\"chat_id\":\"$C\",\"parse_mode\":\"HTML\",\"text\":\"$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk '{o=$0; printf "%s%s", sep, o; sep="\\n"}')\"}" \
    "https://api.telegram.org/bot$T/sendMessage" >/dev/null
}

stamp() { date '+%d.%m %H:%M'; }

# --- brute-force (auth fails за останній час) ---
FAILS=$(logread | grep -ci 'auth.*fail\|password.*fail\|login.*fail' 2>/dev/null)
PREV=$(cat "$DIR/an_fail" 2>/dev/null || echo 0)
if [ "${FAILS:-0}" -ge $((PREV+20)) ]; then
  send_alert "🚨 <b>Підозра на brute-force</b>
Невдалих авторизацій: <code>$FAILS</code> (+$((FAILS-PREV)) з минулої перевірки)
Перевірка: logread | grep -i fail | tail"
fi
echo "${FAILS:-0}" > "$DIR/an_fail"

# --- диск ---
DFU=$(df / | tail -n1 | awk '{gsub(/%/,""); print $5}')
if [ "${DFU:-0}" -ge 90 ]; then
  case "$(cat "$DIR/an_disk" 2>/dev/null)" in 90|9[1-9]|100) ;; *) send_alert "💾 <b>Диск заповнено на ${DFU}%</b>
Очистити: rm /tmp/*.tar.gz ; logread &gt; /dev/null" ;; esac
fi
echo "$DFU" > "$DIR/an_disk"
[ "$DFU" -lt 85 ] && rm -f "$DIR/an_disk"

# --- температура ---
TM=$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1)
if [ "${TM:-0}" -ge 80000 ]; then
  TT=$((TM/1000))
  case "$(cat "$DIR/an_temp" 2>/dev/null)" in 8*|9*|10*) ;; *) send_alert "🌡 <b>Перегрів: ${TT}°C</b>
Перевір вентиляцію; при 90°C можливий тротлінг." ;; esac
  echo "$TT" > "$DIR/an_temp"
else
  rm -f "$DIR/an_temp"
fi

# --- DHCP пул ---
if [ -s /tmp/dhcp.leases ]; then
  USED=$(wc -l < /tmp/dhcp.leases)
  LIM=$(uci -q get dhcp.@dhcp[0].limit 2>/dev/null || echo 150)
  if [ "$USED" -ge $((LIM-2)) ]; then
    case "$(cat "$DIR/an_pool" 2>/dev/null)" in alert) ;; *) send_alert "📡 <b>DHCP-пул майже вичерпано</b>: $USED з $LIM
Розширити: uci set dhcp.@dhcp[0].limit='200'" ;; esac
    echo alert > "$DIR/an_pool"
  else
    rm -f "$DIR/an_pool"
  fi
fi
