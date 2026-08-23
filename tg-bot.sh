#!/bin/sh
# tg-bot.sh — Telegram-бот управления OpenWrt
# Пульс + команды + inline-кнопки + backup + алиасы + присутствие
# + QR Wi-Fi + скан сетей + мониторинг хостов
# Запускается как демон через procd (/etc/init.d/tg-bot)

TOKEN="$(uci -q get tgbot.config.token)"
CHAT="$(uci -q get tgbot.config.chatid)"
[ -z "$TOKEN" ] && exit 0
[ -z "$CHAT" ] && exit 0
API="https://api.telegram.org/bot$TOKEN"
DIR="/etc/tg-bot"
PULSE_INTERVAL=3600
LONGPOLL=25

MENU_MARKUP='{"inline_keyboard":[[{"text":"📊 Статус","callback_data":"st"},{"text":"📱 Устройства","callback_data":"dv"}],[{"text":"📡 Wi-Fi скан","callback_data":"scn"},{"text":"🔑 QR Wi-Fi","callback_data":"qr"}],[{"text":"💾 Бэкап","callback_data":"bk"},{"text":"🤖 AI-чат","callback_data":"aion"}],[{"text":"👀 Слежка","callback_data":"wch"},{"text":"🏷 Имена","callback_data":"al"}],[{"text":"🌐 Интернет","callback_data":"wan"},{"text":"⚡️ Перезагрузка","callback_data":"rb1"}],[{"text":"❓ Помощь","callback_data":"hlp"}]]}'
CONFIRM_MARKUP='{"inline_keyboar'\
'd":[[{"text":"✅ Да, перезагрузить!","callback_data":"rbyes"},{"text":"❌ Отмена","callback_data":"rbno"}]]}'
AI_CONF_MARKUP='{"inline_keyboard":[[{"text":"✅ Выполнить","callback_data":"aic1"},{"text":"❌ Отмена","callback_data":"aic0"}]]}'
AI_MARKUP='{"inline_keyboard":[[{"text":"⛔️ Выйти из AI","callback_data":"aioff"}]]}'

mkdir -p "$DIR"

esc() {
  printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'
}

reply_rich() {
  # $1=текст модели с тегами b/i/u/s/code/pre/blockquote -> безопасная отправка
  E=$(printf '%s' "$1" \
    | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' \
    | sed 's/&lt;b&gt;/<b>/g; s/&lt;\/b&gt;/<\/b>/g; s/&lt;i&gt;/<i>/g; s/&lt;\/i&gt;/<\/i>/g; s/&lt;u&gt;/<u>/g; s/&lt;\/u&gt;/<\/u>/g; s/&lt;s&gt;/<s>/g; s/&lt;\/s&gt;/<\/s>/g; s/&lt;code&gt;/<code>/g; s/&lt;\/code&gt;/<\/code>/g; s/&lt;pre&gt;/<pre>/g; s/&lt;\/pre&gt;/<\/pre>/g; s/&lt;blockquote&gt;/<blockquote>/g; s/&lt;\/blockquote&gt;/<\/blockquote>/g')
  R=$(curl -s --max-time 15 "$API/sendMessage" \
    -d "chat_id=$CHAT" -d "parse_mode=HTML" \
    --data-urlencode "text=$E")
  echo "$R" | grep -q '"ok":true' && return
  P=$(printf '%s' "$1" | sed 's/<[^>]*>//g')
  R2=$(curl -s --max-time 15 "$API/sendMessage" \
    -d "chat_id=$CHAT" -d "parse_mode=HTML" \
    --data-urlencode "text=$(esc "$P")")
  echo "$R2" | grep -q '"ok":true' || echo "$R" > "$DIR/lasterr"
}

reply() {
  R=$(curl -s --max-time 15 "$API/sendMessage" \
    -d "chat_id=$CHAT" -d "parse_mode=HTML" \
    --data-urlencode "text=$1")
  echo "$R" | grep -q '"ok":true' || echo "$R" > "$DIR/lasterr"
}

reply_doc() {
  # $1=file $2=caption
  curl -s --max-time 90 "$API/sendDocument" \
    -F "chat_id=$CHAT" -F "parse_mode=HTML" \
    -F "document=@$1" --form-string "caption=$2" > "$DIR/lastdoc" 2>/dev/null
  grep -q '"ok":true' "$DIR/lastdoc" || mv "$DIR/lastdoc" "$DIR/lasterr"
  rm -f "$DIR/lastdoc"
}

reply_photo_url() {
  curl -s --max-time 30 "$API/sendPhoto" \
    -F "chat_id=$CHAT" -F "photo=$1" --form-string "caption=$2" \
    | grep -q '"ok":true' || echo "sendPhoto fail: $1" > "$DIR/lasterr"
}

reply_photo_file() {
  curl -s --max-time 30 "$API/sendPhoto" \
    -F "chat_id=$CHAT" -F "photo=@$1" --form-string "caption=$2" \
    | grep -q '"ok":true' || echo "sendPhoto(file) fail" > "$DIR/lasterr"
  rm -f "$1"
}

send_menu() {
  curl -s --max-time 15 "$API/sendMessage" \
    -d "chat_id=$CHAT" -d "parse_mode=HTML" \
    --data-urlencode "text=${1:-🤖 Меню роутера}" \
    -d "reply_markup=$MENU_MARKUP" >/dev/null
}

send_mk() {
  # $1=текст $2=reply_markup JSON
  curl -s --max-time 15 "$API/sendMessage" \
    -d "chat_id=$CHAT" -d "parse_mode=HTML" \
    --data-urlencode "text=$1" \
    ${2:+-d "reply_markup=$2"} >/dev/null
}

edit_msg() {
  curl -s --max-time 15 "$API/editMessageText" \
    -d "chat_id=$CHAT" -d "message_id=$1" -d "parse_mode=HTML" \
    ${3:+-d "reply_markup=$3"} \
    --data-urlencode "text=$2" >/dev/null
}

answer_cb() {
  curl -s --max-time 10 "$API/answerCallbackQuery" \
    -d "callback_query_id=$1" >/dev/null
}

typing() {
  # $1=typing|upload_document|upload_photo (индикатор в чате)
  curl -s --max-time 10 "$API/sendChatAction" \
    -d "chat_id=$CHAT" -d "action=${1:-typing}" >/dev/null
}

register_commands() {
  # Список команд для кнопки ☰ Menu в Telegram
  CMDS='{"commands":[{"command":"status","description":"📊 Статус роутера"},{"command":"devices","description":"📱 Устройства в сети"},{"command":"wan","description":"🌐 Перезапустить интернет"},{"command":"backup","description":"💾 Бэкап конфигов файлом"},{"command":"qr","description":"🔑 QR-код для Wi-Fi"},{"command":"scan","description":"📡 Скан сетей вокруг"},{"command":"ai","description":"🤖 Спросить AI про роутер"},{"command":"alias","description":"🏷 Имя устройству: /alias IP Имя"},{"command":"watch","description":"👀 Слежка за людьми"},{"command":"mon","description":"👁 Мониторинг хостов"},{"command":"reboot","description":"⚡️ Перезагрузка: /reboot yes"},{"command":"help","description":"❓ Помощь"}]}'
  curl -s --max-time 15 "$API/setMyCommands" \
    --data-urlencode "commands=$CMDS" | grep -q '"ok":true' || {
    sleep 5
    curl -s --max-time 15 "$API/setMyCommands" \
      --data-urlencode "commands=$CMDS" | grep -q '"ok":true' \
      || echo "setMyCommands fail" > "$DIR/lasterr"
  }
}

pulse_send() {
  curl -s --max-time 15 "$API/sendMessage" \
    -d "chat_id=$CHAT" -d "parse_mode=HTML" \
    --data-urlencode "text=$1" \
    -d "reply_markup=$MENU_MARKUP" \
    | grep -o '"message_id":[0-9]*' | grep -o '[0-9]*' > "$DIR/msgid"
}

pulse_edit_or_send() {
  MSGID=""
  [ -f "$DIR/msgid" ] && MSGID=$(cat "$DIR/msgid")
  if [ -n "$MSGID" ]; then
    R=$(curl -s --max-time 15 "$API/editMessageText" \
      -d "chat_id=$CHAT" -d "message_id=$MSGID" -d "parse_mode=HTML" \
      -d "reply_markup=$MENU_MARKUP" --data-urlencode "text=$1")
    echo "$R" | grep -q '"ok":true' && return
  fi
  pulse_send "$1"
}

uptime_short() {
  U=$(uptime | sed 's/.*up //; s/, *[0-9]* users*//; s/, *load average.*//')
  case "$U" in
    *" min"*|*" min,"*)
      MIN=$(printf '%s' "$U" | cut -d' ' -f1)
      printf '%s мин' "$MIN"
      ;;
    *day*)
      D=$(printf '%s' "$U" | cut -d' ' -f1)
      HM=$(printf '%s' "$U" | awk -F', ' '{print $2}')
      H=${HM%%:*}
      M=${HM##*:}
      printf '%s дн %s ч %s мин' "$D" "$H" "$M"
      ;;
    *:*)
      H=${U%%:*}
      M=${U##*:}
      printf '%s ч %s мин' "$H" "$M"
      ;;
    *)
      printf '%s' "$U"
      ;;
  esac
}

alias_help() {
  printf "<b>🏷 Свои имена устройств</b>\n\nЗадать имя:\n<code>/alias 192.168.1.105 Ноутбук</code>\n\nУбрать имя:\n<code>/alias del 192.168.1.105</code>\n\nИмена видны в 📱 Устройствах и в 👀 Слежке."
}

watch_menu_ui() {
  T=/tmp/tg-w.$$
  awk '{print $3"|"$4"|"$2}' /tmp/dhcp.leases 2>/dev/null | sort -t'|' -k1,1 -u > "$T"
  ROWS=""
  ROW=""
  CNT=0
  while IFS='|' read -r IP NM MAC; do
    A=$(alias_of "$IP")
    [ -n "$A" ] && NM="$A"
    [ "$NM" = "*" ] && NM=""
    [ -z "$NM" ] && NM="уст-во.${IP##*.}"
    E=$(esc "$NM" | sed 's/"/\\"/g')
    INW=$(grep -ci "^${MAC}|" "$DIR/presence.cfg" 2>/dev/null)
    if [ "${INW:-0}" != "0" ]; then
      BTN="{\"text\":\"✅ $E\",\"callback_data\":\"wdel:$MAC\"}"
    else
      BTN="{\"text\":\"$E\",\"callback_data\":\"wadd:$MAC\"}"
    fi
    if [ $((CNT % 2)) -eq 0 ]; then
      [ -n "$ROW" ] && { ROWS="$ROWS[$ROW],"; ROW=""; }
      ROW="$BTN"
    else
      ROW="$ROW,$BTN"
    fi
    CNT=$((CNT+1))
  done < "$T"
  rm -f "$T"
  [ -n "$ROW" ] && ROWS="$ROWS[$ROW],"
  ROWS="${ROWS}[{\"text\":\"⬅️ Меню\",\"callback_data\":\"mn\"}]"
  WTXT="<b>👀 Слежка за людьми</b>
Тапните по человеку — бот сообщит о
приходе 🏠 и уходе 👋 (по MAC телефона)

✅ — уже под наблюдением (тап = убрать)"
  [ "$CNT" = "0" ] && WTXT="<b>👀 Слежка за людьми</b>

Пока никто не найден в DHCP-арендах."
  WMK="{\"inline_keyboard\":[$ROWS]}"
}

internet_ok() {
  ping -c1 -W2 8.8.8.8 >/dev/null 2>&1 && echo "✅ есть" || echo "❌ нет"
}

status_text() {
  MEM=$(free | awk '/Mem:/ {printf "%d из %d МБ занято", $3/1024, $2/1024}')
  WANIP=$(ip addr show wan 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1)
  PUBIP=$(curl -s --max-time 5 https://api.ipify.org)
  NET=$(internet_ok)
  printf "<b>📊 Статус роутера</b>\n⏱ Аптайм: <code>%s</code>\n📈 Load: <code>%s</code>\n🧠 RAM: <code>%s</code>\n🌐 WAN: <code>%s</code>\n🌍 Публичный IP: <code>%s</code>\n🔗 Интернет: %s\n🕐 <i>%s</i>\n" \
    "$(uptime_short)" \
    "$(cut -d' ' -f1-3 /proc/loadavg)" \
    "$MEM" \
    "${WANIP:-нет}" \
    "${PUBIP:-?}" \
    "$NET" \
    "$(date '+%d.%m.%Y %H:%M:%S')"
}

alias_of() {
  # $1=IP -> имя из /etc/tg-bot/aliases или пусто
  [ -f "$DIR/aliases" ] && grep -m1 "^$1|" "$DIR/aliases" | cut -d'|' -f2
}

devices_text() {
  T=/tmp/tg-devs.$$
  AT=/tmp/tg-arp.$$
  awk '$3=="0x2" && $1 ~ /^192\.168\./ {print $1}' /proc/net/arp > "$AT"

  if [ ! -s /tmp/dhcp.leases ]; then
    echo "📭 DHCP-аренды не найдены"
    rm -f "$AT"
    return
  fi

  awk '{print $3"|"$4"|"$2}' /tmp/dhcp.leases \
    | sort -t'|' -k1,1 -u > "$T"

  ONLINE=0
  TOTAL=0
  ON=""
  OFF=""
  while IFS='|' read -r IP NAME MAC; do
    TOTAL=$((TOTAL+1))
    A=$(alias_of "$IP")
    [ -n "$A" ] && NAME="$A"
    [ "$NAME" = "*" ] && NAME=""
    [ -z "$NAME" ] && NAME="устройство-${IP##*.}"
    [ ${#NAME} -gt 40 ] && NAME=$(printf '%s' "$NAME" | head -c 40)
    NAME=$(esc "$NAME")
    if grep -qxF "$IP" "$AT"; then
      ONLINE=$((ONLINE+1))
      ON="$ON🟢 <b>$NAME</b> · $IP\n"
    else
      OFF="$OFF⚪️ $NAME · $IP\n"
    fi
  done < "$T"

  printf '<b>📶 Устройства</b> · 🟢 онлайн: %s из %s\n' "$ONLINE" "$TOTAL"
  [ -n "$ON" ] && printf '\n<b>📍 В сети</b>\n%s' "$(printf '%b' "$ON")"
  [ -n "$OFF" ] && printf '\n\n<b>📍 Не в сети</b>\n%s' "$(printf '%b' "$OFF")"
  rm -f "$T" "$AT"
}

help_text() {
  printf "<b>🤖 Управление роутером</b>\n\n<b>📍 Основное</b>\n<code>/status</code> · статус системы\n<code>/devices</code> · устройства в сети\n<code>/wan</code> · переподключить интернет\n<code>/reboot yes</code> · перезагрузка\n\n<b>📍 Инструменты</b>\n<code>/backup</code> · бэкап конфигов файлом сюда\n<code>/qr</code> · QR для подключения к Wi-Fi\n<code>/scan</code> · скан соседних сетей\n<code>/ai вопрос</code> · спросить AI (видит статус сети)\n\n<b>📍 Алиасы и слежка</b>\n<code>/alias IP Имя</code> · своё имя устройству\n<code>/alias del IP</code> · убрать имя\n<code>/watch add MAC Имя</code> · следить за человеком\n<code>/watch list|del MAC</code>\n<code>/mon add host Метка</code> · следить за хостом\n<code>/mon list|del host</code>\n\n✅ <i>Пульс ежечасный: время устарело — роутер лежит.</i>"
}

menu_text() {
  printf '🤖 <b>Роутер</b> · ⏱ %s · 🔗 %s\nВыбирайте кнопки 👇' \
    "$(uptime_short)" "$(internet_ok)"
}

# --- новые команды ---

cmd_backup() {
  TS=$(date '+%Y%m%d-%H%M')
  B="/tmp/tg-backup-$TS.tar.gz"
  typing
  reply "📦 Собираю бэкап..."
  (cd / && tar -czf "$B" etc/config etc/tg-bot etc/crontabs/root 2>/dev/null)
  if [ -s "$B" ]; then
    reply_doc "$B" "💾 Бэкап конфигов сохранен в файл.
Файл сохранен locally. Можно переслать его боту и сделать /restore для восстановления."
  else
    reply "❌ Не удалось создать архив"
  fi
  rm -f "$B"
}

cmd_alias() {
  # /alias IP [Имя...] | /alias del IP
  OP=$(echo "$1" | awk '{print tolower($2)}')
  if [ "$OP" = "del" ]; then
    IP=$(echo "$1" | awk '{print toupper($3)}')
    [ -z "$IP" ] && { reply "Формат: /alias del IP"; return; }
    grep -v "^$IP|" "$DIR/aliases" 2>/dev/null > "$DIR/aliases.new"
    mv "$DIR/aliases.new" "$DIR/aliases"
    reply "🗑 Алиас $IP удалён"
    return
  fi
  IP=$(echo "$1" | awk '{print toupper($2)}')
  NM=$(echo "$1" | awk '{out=""; for(i=3;i<=NF;i++) out=out (i>3?" ":"") $i; print out}')
  if [ -z "$IP" ] || [ -z "$NM" ]; then
    reply "Формат: /alias 192.168.1.105 Ноутбук"
    return
  fi
  echo "$1" | grep -qE "/alias +[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3} +" \
    || { reply "❌ IP выглядит странно"; return; }
  grep -v "^$IP|" "$DIR/aliases" 2>/dev/null > "$DIR/aliases.new"
  mv "$DIR/aliases.new" "$DIR/aliases"
  echo "$IP|$NM" >> "$DIR/aliases"
  reply "🏷 Готово: $IP = <b>$(esc "$NM")</b>"
}

cmd_watch() {
  # /watch add MAC Имя | /watch del MAC | /watch list
  OP=$(echo "$1" | awk '{print tolower($2)}')
  CF="$DIR/presence.cfg"
  touch "$CF"
  if [ "$OP" = "list" ]; then
    N=$(grep -c . "$CF" 2>/dev/null)
    if [ "$N" = "0" ] || [ -z "$N" ]; then
      reply "👀 Список пуст. Добавить: /watch add AA:BB:CC:DD:EE:FF Жена"
    else
      MSG="<b>👀 Наблюдаемые:</b>"
      while IFS='|' read -r MC NM; do
        MSG="$MSG
🟢 <code>$MC</code> · $(esc "$NM")"
      done < "$CF"
      reply "$MSG"
    fi
    return
  fi
  MC=$(echo "$1" | awk '{print toupper($3)}')
  echo "$MC" | grep -qE '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' || { reply "Формат MAC: AA:BB:CC:DD:EE:FF"; return; }
  if [ "$OP" = "del" ]; then
    grep -vi "^$MC|" "$CF" > "$CF.new"; mv "$CF.new" "$CF"
    grep -vi "^$MC|" "$DIR/presence.state" 2>/dev/null > "$DIR/presence.state.new"
    mv "$DIR/presence.state.new" "$DIR/presence.state" 2>/dev/null
    reply "🗑 Убрал из наблюдения"
    return
  fi
  NM=$(echo "$1" | awk '{out=""; for(i=4;i<=NF;i++) out=out (i>4?" ":"") $i; print out}')
  [ -z "$NM" ] && NM="гость-${MC##*:}"
  grep -vi "^$MC|" "$CF" > "$CF.new"; mv "$CF.new" "$CF"
  echo "$MC|$NM" >> "$CF"
  reply "👀 Следую за <b>$(esc "$NM")</b> (<code>$MC</code>)
Сообщу о приходе/уходе 🏠👋"
}

cmd_mon() {
  # /mon add host Метка | /mon del host | /mon list
  OP=$(echo "$1" | awk '{print tolower($2)}')
  CF="$DIR/mon.cfg"
  touch "$CF"
  if [ "$OP" = "list" ]; then
    N=$(grep -c . "$CF" 2>/dev/null)
    if [ "$N" = "0" ] || [ -z "$N" ]; then
      reply "📭 Список пуст. Добавить: /mon add nas.local 🗄NAS"
    else
      MSG="<b>👁 Мониторинг хостов:</b>"
      while IFS='|' read -r H LB ST; do
        [ "$ST" = "1" ] && S="🟢" || S="⚫️"
        MSG="$MSG
$S <code>$H</code> · $(esc "$LB")"
      done < "$CF"
      reply "$MSG"
    fi
    return
  fi
  H=$(echo "$1" | awk '{print $3}')
  [ -z "$H" ] && { reply "Формат: /mon add 192.168.1.50 NAS"; return; }
  if [ "$OP" = "del" ]; then
    grep -v "^$H|" "$CF" > "$CF.new"; mv "$CF.new" "$CF"
    reply "🗑 Убрал из мониторинга"
    return
  fi
  LB=$(echo "$1" | awk '{out=""; for(i=4;i<=NF;i++) out=out (i>4?" ":"") $i; print out}')
  [ -z "$LB" ] && LB="$H"
  grep -v "^$H|" "$CF" > "$CF.new"; mv "$CF.new" "$CF"
  echo "$H|$LB|?" >> "$CF"
  reply "👁 Следю за <code>$H</code> ($(esc "$LB")) — сообщу о падении/восстановлении"
}

wifi_creds() {
  SSID=$(uci -q show wireless 2>/dev/null | sed -n "s/^wireless\.[^.]*\.ssid='\([^']*\)'.*/\1/p" | head -1)
  KEY=$(uci -q show wireless 2>/dev/null | sed -n "s/^wireless\.[^.]*\.key='\([^']*\)'.*/\1/p" | head -1)
}

cmd_qr() {
  wifi_creds
  if [ -z "$SSID" ]; then
    reply "❌ Не нашёл настройки Wi-Fi"
    return
  fi
  ESC_S=$(printf '%s' "$SSID" | sed 's/[\\;,:"]/\\&/g')
  ESC_K=$(printf '%s' "$KEY" | sed 's/[\\;,:"]/\\&/g')
  DATA="WIFI:T:WPA;S:$ESC_S;P:$ESC_K;;"
  QRURL="https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=$(printf '%s' "$DATA" | sed 's/:/%3A/g; s/;/%3B/g')"
  reply_photo_url "$QRURL" "📶 Сеть: <b>$(esc "$SSID")</b>
Наведите камеру для подключения
<i>QR создан через внешний сервис api.qrserver.com</i>"
}

jesc() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n\r\t' '   '
}

ai_snapshot() {
  SNAP="аптайм: $(uptime_short); RAM: $(free | awk '/Mem:/ {printf "%d из %d МБ занято", $3/1024, $2/1024}'); интернет: $(internet_ok); load: $(cut -d' ' -f1 /proc/loadavg); WAN IP: $(ip addr show wan 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1)"
  DEVS=$(devices_text | sed 's/<[^>]*>//g' | tr '\n' ';' | sed 's/;[[:space:]]*;/; /g')
}

ai_rules() {
  printf '%s' "Ты — AI-агент в Telegram-боте домашнего роутера. Железо/ОС: Xiaomi Mi Router 4A Gigabit, OpenWrt 25.12, busybox ash, пакеты ставятся ТОЛЬКО через apk (opkg НЕТ).
Ты выполняешь ОДНУ shell-команду за ход (можно составную через ; или &&), вывод вернётся сообщением 'РЕЗУЛЬТАТ КОМАНДЫ', при ошибке будет пометка с кодом выхода.
Доступно: uci, ubus call, iwinfo, logread, jsonfilter, curl, tar, timeout, crontab, ip, df, top.
НЕТ и не предлагай ставить: python, jq, iwlist, iwconfig, openssl, base64, sudo. Если команда вернула ошибку или not found — следующим шагом CMD молча пробуй другой способ.
Рецепты частых задач:
- Wi-Fi: список клиентов: iwinfo ; SSID: uci -q get wireless.@wifi-iface[0].ssid ; пароль: .key ; канал/мощность: wireless.radio0.channel/.txpower ; применить: uci commit wireless && wifi reload
- LAN/DHCP: network.lan.ipaddr, dhcp.@dhcp[0] (start/limit/leasetime) ; статический IP: uci add dhcp host; uci set dhcp.@host[-1].name='имя' .mac='AA:BB:CC:DD:EE:FF' .ip='IP' ; uci commit dhcp ; применение network-изменений: uci commit network && /etc/init.d/network restart (связь оборвётся ~30 сек!)
- WireGuard/VPN: apk add wireguard-tools luci-proto-wireguard kmod-wireguard ; интерфейс: uci set network.wg0=interface, network.wg0.proto='wireguard', адреса; приватный ключ в файл /etc/wireguard/*.key, пиры через секции wireguard_wg0 ; затем /etc/init.d/network restart
- Файрвол: посмотреть: uci show firewall ; правило: uci add firewall rule; uci set firewall.@rule[-1].name='..' .src='lan' .dest='wan' ... ; uci commit firewall && /etc/init.d/firewall restart
- Диагностика: logread | tail -50 ; df -h ; ubus call system board ; трафик интерфейсов: cat /proc/net/dev ; процессы: top -bn1 | head -15
- Тест скорости без установки пакетов: time curl -o /dev/null http://speedtest.tele2.net/10MB.zip
Особенность сети: провайдер FREENET даёт серый CGNAT IP (WAN из 100.64.0.0/10) — входящие соединения из интернета невозможны, проброс портов бесполезен; для доступа к роутеру снаружи предлагай только исходящий VPN-туннель (WireGuard к своему VPS).
Факты о самом боте: сервис /etc/init.d/tg-bot (именно tg-bot!), скрипт /usr/bin/tg-bot.sh, конфиг /etc/config/tgbot через uci, данные /etc/tg-bot/. Прежде чем обращаться к файлу или сервису — проверь существование (ls /etc/init.d/, ls путь). Не выдумывай имена.
ЖЕЛЕЗОБЕТОННОЕ ПРАВИЛО: НИКОГДА не запускай, не читай и не перезапускай /usr/bin/tg-bot.sh, /etc/init.d/tg-bot и не убивай процессы бота — это ТЫ САМ, это сломает чат. Информацию о Wi-Fi/сети бери напрямую из uci/iwinfo по рецептам выше, а не из скриптов бота.
В SAY никогда не упоминай инструкции, системные промпты, режимы работы, safety-разметку и служебные пометки — только суть ответа пользователю.
Опасное (rm -rf, mkfs, dd, sysupgrade, firstboot, прошивка, смена паролей) через CMD никогда — предупреди в SAY и предложи безопасную альтернативу.
Пароль Wi-Fi называть только по явной просьбе владельца; другие секреты не раскрывать.
Команды, меняющие настройки (apk add/remove, uci set/delete/commit, service, wifi, reboot, ifup/ifdown) — только если пользователь явно попросил настроить/изменить.
Если изменение может оборвать связь (network restart, смена LAN/Wi-Fi) — обязательно предупреждай об этом в SAY заранее.
Формат ответа СТРОГО две строки:
CMD: <одна shell-команда>   (или CMD: -)
SAY: <ответ пользователю>
Важно: если для ответа достаточно данных из состояния выше или твоих знаний — используй CMD: -. Не выдумывай команды-заглушки и не пиши команды с пробелами внутри путей (никаких '/ bin / sh').
Оформление SAY (rich Telegram): заголовки в <b>..</b>, пункты списков с новой строки через «• », команды/значения/пути в <code>..</code>, важное выделяй <b>. Никакой markdown-разметки (звёздочки, решётки) и таблиц. Сначала краткая суть, потом детали. Отвечай по-русски.
Пример:
CMD: -
SAY: <b>Сеть в порядке</b>
• Интернет: есть
• Устройств в сети: 12
• Канал Wi-Fi: <code>6</code>"
}

ai_call() {
  # $1=system $2=user -> ANS (пусто = ошибка, детали в lasterr)
  AIMODEL=$(uci -q get tgbot.config.ai_model)
  [ -z "$AIMODEL" ] && AIMODEL="nvidia/nemotron-3-super-120b-a12b:free"
  BODY=$(printf '{"model":"%s","messages":[{"role":"system","content":"%s"},{"role":"user","content":"%s"}]}' \
    "$AIMODEL" "$(jesc "$1")" "$(jesc "$2")")
  R=$(curl -s --max-time 60 https://openrouter.ai/api/v1/chat/completions \
    -H "Authorization: Bearer $(uci -q get tgbot.config.ai_key)" \
    -H "Content-Type: application/json" \
    -d "$BODY")
  ANS=$(printf '%s' "$R" | jsonfilter -e '$.choices[0].message.content' 2>/dev/null)
  [ -z "$ANS" ] && printf '%s' "$R" | head -c 300 > "$DIR/lasterr"
  ANS=$(printf '%s' "$ANS" | sed 's/```[a-zA-Z]*//g; s/```//g')
}

is_mut() {
  case "$1" in
    "uci "*|reboot*|service*|/etc/init.d/*|"wifi "*|ifup*|ifdown*|"opkg "*|\
    "rm "*|"mv "*|"cp "*"ln "*"mkdir "*"touch "*|passwd*|chmod*|chown*|\
    mount*|umount*|sysupgrade*|firstboot*) return 0 ;;
    *) return 1 ;;
  esac
}

ai_run() {
  if printf '%s' "$1" | grep -qE '(rm +-[a-zA-Z]*r[a-zA-Z]* *f?|mkfs|dd +if=|sysupgrade|firstboot)'; then
    OUT="ОТКАЗ: запрещённая команда"
    return
  fi
  if command -v timeout >/dev/null 2>&1; then
    OUT=$(timeout 20 sh -c "$1" 2>&1 | head -c 1200)
  else
    OUT=$(sh -c "$1" 2>&1 | head -c 1200)
  fi
  [ -z "$OUT" ] && OUT="(выполнено без вывода)"
}

ai_agent() {
  [ -z "$(uci -q get tgbot.config.ai_key)" ] && {
    reply "🤖 AI не настроен — нет ключа OpenRouter."
    return
  }
  Q=$(printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  if [ "$Q" = "off" ]; then
    rm -f "$DIR/aimode"
    reply "⛔️ Вышел из AI-чата."
    return
  fi
  [ -z "$Q" ] && { reply "🤖 Напишите вопрос текстом. Выйти: /ai off"; return; }
  reply "🤔 Думаю..."
  ( N=0; while [ $N -lt 40 ]; do typing; sleep 4; N=$((N+1)); done ) &
  TPID=$!
  ai_snapshot
  HIST=""
  [ -s "$DIR/aihist" ] && HIST="
Предыдущий диалог:
$(tail -c 1000 "$DIR/aihist")"
  SYS="$(ai_rules)
Состояние роутера сейчас: $SNAP
Устройства в сети: $DEVS$HIST"
  CUR="$Q"
  STEP=0
  FSAY=""
  while [ $STEP -lt 3 ]; do
    STEP=$((STEP+1))
    [ $STEP -gt 1 ] && CUR="РЕЗУЛЬТАТ КОМАНДЫ '$PCMD':
$OUT"
    ai_call "$SYS" "$CUR"
    [ -z "$ANS" ] && break
    PCMD=$(printf '%s' "$ANS" | sed -n 's/^CMD:[[:space:]]*//p' | head -1)
    FSAY=$(printf '%s' "$ANS" | sed -n 's/^SAY:[[:space:]]*//p' | head -1)
    if [ -z "$FSAY" ] && [ -z "$PCMD" ]; then
      FSAY=$(printf '%s' "$ANS" | sed '/./,$!d' | head -c 600)
    elif [ -z "$FSAY" ]; then
      FSAY=$(printf '%s' "$ANS" | grep -v '^CMD:' | tr '\n' ' ' | head -c 600)
    fi
    PSTRIP=$(printf '%s' "$PCMD" | tr -d ' \t\r\n')
    case "$PSTRIP" in
      ""|"-"|"--"|*"–"*|*"—"*)
        break
        ;;
    esac
    if is_mut "$PCMD"; then
      kill "$TPID" 2>/dev/null
      printf '%s' "$PCMD" > "$DIR/aipend"
      reply "🤖 Хочу выполнить:
<code>$(esc "$PCMD")</code>
Это меняет настройки роутера." 
      send_mk "Подтвердите:" "$AI_CONF_MARKUP"
      return
    fi
    reply "⚙️ Выполняю: <code>$(esc "$PCMD")</code>"
    ai_run "$PCMD"
  done
  kill "$TPID" 2>/dev/null
  [ -z "$FSAY" ] && FSAY="Не получил ответ модели. Детали: /etc/tg-bot/lasterr"
  FSAY=$(printf '%s' "$FSAY" | awk '/<system-reminder>/{s=1} /<\/system-reminder>/{s=0; next} !s' | sed '/^[[:space:]]*$/d')
  reply_rich "🤖 $FSAY"
  { printf 'Пользователь: %.300s\nАссистент: %.300s\n' "$Q" "$FSAY"; } >> "$DIR/aihist"
  tail -c 2000 "$DIR/aihist" > "$DIR/aihist.t" 2>/dev/null && mv "$DIR/aihist.t" "$DIR/aihist"
}

cmd_scan() {
  IFACE=$(iwinfo 2>/dev/null | head -1 | awk '{print $1}')
  [ -z "$IFACE" ] && { reply "❌ Сканирование не поддерживается"; return; }
  reply "📡 Сканирую ($IFACE)..."
  RAW=$(iwinfo "$IFACE" scan 2>/dev/null)
  [ -z "$RAW" ] && { reply "❌ Пустой результат скана"; return; }

  T=/tmp/tg-scan.$$
  printf '%s\n' "$RAW" | awk '
    /^Cell / {
      if (essid != "") printf "%s|%s|%s\n", ch, sig, essid;
      essid=""; ch=""; sig=""
    }
    /Frequency:/ {
      for (i=1;i<=NF;i++) if ($i=="Channel:") ch=$(i+1)
    }
    /Signal:/ {
      for (i=1;i<=NF;i++) if ($i=="Signal:") sig=$(i+1)
    }
    /ESSID:/ {
      e=$0; sub(/.*ESSID: */,"",e); gsub(/^"|"$/,"",e);
      if (e=="") e="(скрытая)";
      essid=e
    }
    END {
      if (essid != "") printf "%s|%s|%s\n", ch, sig, essid
    }' | sort -t'|' -k1,1n -k2,2rn > "$T"

  C24=$(awk -F'|' '$1<=13 {c[$1]++} END{for(i in c) print i":"c[i]}' "$T" | sort -t: -k1,1n | tr '\n' ' ')
  BEST=""
  MIN=99999
  for CAND in 1 6 11; do
    N=$(printf '%s' "$C24" | tr ' ' '\n' | grep "^$CAND:" | cut -d: -f2)
    N=${N:-0}
    if [ "$N" -lt "$MIN" ]; then MIN=$N; BEST=$CAND; fi
  done

  TOP=$(head -10 "$T" | awk -F'|' '{printf "%s dBm  ch%-3s %s\n", $2, $1, substr($3,1,24)}')
  NALL=$(wc -l < "$T")
  MSG="<b>📡 Сети вокруг</b>

📻 <b>Занятость каналов 2.4:</b>
<code>$C24</code>
💡 Совет: канал <b>$BEST</b> свободнее всех

<b>📍 Топ по сигналу:</b>
<code>$TOP</code>

Всего сетей: <i>$NALL</i>"
  reply "$MSG"
  rm -f "$T"
}

# --- периодические проверки (раз в минуту) ---
do_checks() {
  # --- присутствие людей ---
  PCFG="$DIR/presence.cfg"
  PST="$DIR/presence.state"
  if [ -s "$PCFG" ]; then
    touch "$PST"
    ARP_MACS=$(awk '$3=="0x2"{print tolower($4)}' /proc/net/arp)
    while IFS='|' read -r MC NM; do
      [ -z "$MC" ] && continue
      HERE=0
      echo "$ARP_MACS" | grep -qxF "$(printf '%s' "$MC" | tr 'A-F' 'a-f')" && HERE=1
      if [ "$HERE" != "1" ]; then
        LIP=$(awk -v m="$(printf '%s' "$MC" | tr 'A-F' 'a-f')" 'tolower($2)==m {print $3}' /tmp/dhcp.leases 2>/dev/null | head -1)
        [ -n "$LIP" ] && ping -c1 -W1 "$LIP" >/dev/null 2>&1 && HERE=1
      fi
      PREV=""
      [ -f "$PST" ] && PREV=$(grep "^$MC|" "$PST" | cut -d'|' -f2)
      if [ "$PREV" != "$HERE" ]; then
        grep -v "^$MC|" "$PST" 2>/dev/null > "$PST.new"
        echo "$MC|$HERE" >> "$PST.new"
        mv "$PST.new" "$PST"
        TM=$(date '+%H:%M')
        ENM=$(esc "$NM")
        if [ "$HERE" = "1" ]; then
          reply "🏠 <b>$ENM</b> дома · $TM"
        else
          reply "👋 <b>$ENM</b> ушёл · $TM"
        fi
      fi
    done < "$PCFG"
  fi

  # --- мониторинг хостов ---
  MCFG="$DIR/mon.cfg"
  if [ -s "$MCFG" ]; then
    NEW=""
    while IFS='|' read -r H LB ST; do
      [ -z "$H" ] && continue
      ping -c1 -W2 "$H" >/dev/null 2>&1 && UP=1 || UP=0
      if [ "$ST" != "$UP" ] && [ "$ST" != "?" ]; then
        ELB=$(esc "$LB")
        if [ "$UP" = "1" ]; then
          reply "🟢 <b>$ELB</b> снова в сети · <code>$H</code> · $(date '+%H:%M')"
        else
          reply "🔴 <b>$ELB</b> НЕДОСТУПЕН · <code>$H</code> · $(date '+%H:%M')"
        fi
      fi
      echo "$H|$LB|$UP" >> "${MCFG}.new"
    done < "$MCFG"
    [ -f "${MCFG}.new" ] && mv "${MCFG}.new" "$MCFG"
  fi
}

# --- обработка апдейтов ---
process_updates() {
  OFFSET=0
  [ -f "$DIR/offset" ] && OFFSET=$(cat "$DIR/offset")

  UPDATES=$(curl -s --max-time $((LONGPOLL+15)) "$API/getUpdates?timeout=$LONGPOLL&offset=$OFFSET&allowed_updates=%5B%22message%22,%22callback_query%22%5D")
  [ -z "$UPDATES" ] && sleep 5 && return

  TOTAL=$(jsonfilter -s "$UPDATES" -e '$.result[*].update_id' 2>/dev/null | wc -l)

  i=0
  LAST=""
  while [ "$i" -lt "$TOTAL" ]; do
    UID_=$(jsonfilter -s "$UPDATES" -e "\$.result[$i].update_id" 2>/dev/null)
    LAST="$UID_"

    CID=$(jsonfilter -s "$UPDATES" -e "\$.result[$i].message.chat.id" 2>/dev/null)
    TXT=$(jsonfilter -s "$UPDATES" -e "\$.result[$i].message.text" 2>/dev/null)

    if [ "$CID" = "$CHAT" ]; then
      if [ -n "$TXT" ]; then
        case "$TXT" in
          "/start"|"/menu")
            send_menu "$(menu_text)"
            ;;
          "/help")
            send_menu "$(help_text)"
            ;;
          "/status")
            reply "$(status_text)"
            ;;
          "/devices")
            reply "$(devices_text)"
            ;;
          "/wan")
            reply "🔄 Перезапускаю WAN..."
            ifup wan 2>/dev/null
            ;;
          "/backup")
            cmd_backup
            ;;
          "/qr")
            cmd_qr
            ;;
          "/scan")
            cmd_scan
            ;;
          "/ai"*|"/ai")
            touch "$DIR/aimode"
            ai_agent "${TXT#/ai}"
            ;;
          "/alias "*)
            cmd_alias "$TXT"
            ;;
          "/watch"*|"/watch")
            [ "$TXT" = "/watch" ] && TXT="/watch list"
            cmd_watch "$TXT"
            ;;
          "/mon"*|"/mon")
            [ "$TXT" = "/mon" ] && TXT="/mon list"
            cmd_mon "$TXT"
            ;;
          "/reboot")
            date +%s > "$DIR/rbarm"
            reply "⚠️ Подтвердите: /reboot yes (или кнопкой ниже 👇)"
            send_menu "🤖 Меню:"
            ;;
          "/reboot yes"|"/reboot  yes")
            ARMED=0
            if [ -f "$DIR/rbarm" ]; then
              A=$(cat "$DIR/rbarm")
              [ $(( $(date +%s) - A )) -le 300 ] && ARMED=1
            fi
            if [ "$ARMED" = "1" ]; then
              rm -f "$DIR/rbarm"
              reply "🔄 Перезагружаюсь! Вернусь через ~1-2 минуты."
              sleep 2
              reboot
              exit 0
            else
              reply "⚠️ Сначала /reboot, затем /reboot yes"
            fi
            ;;
          *)
            if [ -f "$DIR/aimode" ]; then
              ai_agent "$TXT"
            else
              send_menu "$(help_text)"
            fi
            ;;
        esac
      fi
    fi

    CB=$(jsonfilter -s "$UPDATES" -e "\$.result[$i].callback_query.data" 2>/dev/null)
    if [ -n "$CB" ]; then
      CFROM=$(jsonfilter -s "$UPDATES" -e "\$.result[$i].callback_query.from.id" 2>/dev/null)
      CBID=$(jsonfilter -s "$UPDATES" -e "\$.result[$i].callback_query.id" 2>/dev/null)
      MSGID_CB=$(jsonfilter -s "$UPDATES" -e "\$.result[$i].callback_query.message.message_id" 2>/dev/null)

      if [ "$CFROM" = "$CHAT" ]; then
        answer_cb "$CBID"
        case "$CB" in
          st)
            reply "$(status_text)"
            ;;
          dv)
            reply "$(devices_text)"
            ;;
          wan)
            reply "🔄 Перезапускаю WAN..."
            ifup wan 2>/dev/null
            ;;
          bk)
            cmd_backup
            ;;
          hlp)
            send_menu "$(help_text)"
            ;;
          aion)
            touch "$DIR/aimode"
            rm -f "$DIR/aihist"
            edit_msg "$MSGID_CB" "🤖 <b>AI-чат включён</b>
Пишите вопрос текстом — я вижу состояние роутера
и могу выполнять команды (настройки — только с подтверждением).
Выйти: /ai off или кнопкой ниже." "$AI_MARKUP"
            ;;
          aioff)
            rm -f "$DIR/aimode"
            edit_msg "$MSGID_CB" "⛔️ Вышел из AI-чата. Обычное меню:" "$MENU_MARKUP"
            ;;
          aic1)
            C=$(cat "$DIR/aipend" 2>/dev/null)
            rm -f "$DIR/aipend"
            if [ -n "$C" ]; then
              ai_run "$C"
              edit_msg "$MSGID_CB" "✅ Выполнено: <code>$(esc "$C")</code>

Результат:
<code>$(esc "${OUT:-(пусто)}")</code>" "$MENU_MARKUP"
            else
              edit_msg "$MSGID_CB" "Нет отложенной команды." "$MENU_MARKUP"
            fi
            ;;
          aic0)
            rm -f "$DIR/aipend"
            edit_msg "$MSGID_CB" "❌ Отменено." "$MENU_MARKUP"
            ;;
          qr)
            cmd_qr
            ;;
          scn)
            cmd_scan
            ;;
          rb1)
            date +%s > "$DIR/rbarm"
            edit_msg "$MSGID_CB" "⚠️ Точно перезагрузить роутер?" "$CONFIRM_MARKUP"
            ;;
          rbyes)
            ARMED=0
            if [ -f "$DIR/rbarm" ]; then
              A=$(cat "$DIR/rbarm")
              [ $(( $(date +%s) - A )) -le 300 ] && ARMED=1
            fi
            if [ "$ARMED" = "1" ]; then
              rm -f "$DIR/rbarm"
              edit_msg "$MSGID_CB" "🔄 Перезагружаюсь! Вернусь через ~1-2 минуты."
              sleep 2
              reboot
            else
              reply "⚠️ Время подтверждения истекло. Нажмите ⚡️ Ребут заново."
            fi
            ;;
          wch)
            watch_menu_ui
            edit_msg "$MSGID_CB" "$WTXT" "$WMK"
            ;;
          wadd:*)
            MC=$(printf '%s' "${CB#wadd:}" | tr 'a-f' 'A-F')
            LMAC=$(printf '%s' "$MC" | tr 'A-F' 'a-f')
            IP=$(awk -v m="$LMAC" 'tolower($2)==m {print $3; exit}' /tmp/dhcp.leases 2>/dev/null)
            NM=$(alias_of "$IP")
            [ -z "$NM" ] && NM=$(awk -v m="$LMAC" 'tolower($2)==m {print $4; exit}' /tmp/dhcp.leases 2>/dev/null)
            [ "$NM" = "*" ] && NM=""
            [ -z "$NM" ] && NM="гость-${MC##*:}"
            grep -vi "^$MC|" "$DIR/presence.cfg" 2>/dev/null > "$DIR/pc.new"
            mv "$DIR/pc.new" "$DIR/presence.cfg"
            echo "$MC|$NM" >> "$DIR/presence.cfg"
            reply "👀 Следую за <b>$(esc "$NM")</b> (<code>$MC</code>)
Сообщу о приходе 🏠 и уходе 👋"
            ;;
          wdel:*)
            MC=$(printf '%s' "${CB#wdel:}" | tr 'a-f' 'A-F')
            NM=$(grep -i "^$MC|" "$DIR/presence.cfg" 2>/dev/null | cut -d'|' -f2)
            grep -vi "^$MC|" "$DIR/presence.cfg" 2>/dev/null > "$DIR/pc.new"
            mv "$DIR/pc.new" "$DIR/presence.cfg"
            reply "🗑 Наблюдение за <b>$(esc "${NM:-$MC}")</b> снято"
            ;;
          mn)
            edit_msg "$MSGID_CB" "$(menu_text)" "$MENU_MARKUP"
            ;;
          al)
            reply "$(alias_help)"
            ;;
          rbno)
            edit_msg "$MSGID_CB" "$(menu_text)" "$MENU_MARKUP"
            ;;
        esac
      fi
    fi

    i=$((i+1))
  done

  if [ -n "$LAST" ]; then
    echo $((LAST+1)) > "$DIR/offset"
  fi
}

# --- ежечасный пульс ---
check_pulse() {
  NOW=$(date +%s)
  LP=0
  [ -f "$DIR/lastpulse" ] && LP=$(cat "$DIR/lastpulse")
  if [ $((NOW-LP)) -ge $PULSE_INTERVAL ]; then
    pulse_edit_or_send "<b>✅ Роутер работает</b>

⏱ Аптайм: $(uptime_short)
🔗 Интернет: $(internet_ok)

🕐 Обновлено: $(date '+%H:%M')
<i>Пульс приходит каждый час.
Если время выше перестало обновляться — роутер был выключен.</i>"
    echo "$NOW" > "$DIR/lastpulse"
  fi
}

# --- регистрация команд в меню Telegram (кнопка ☰) ---
register_commands

# --- главный цикл демона ---
NEXTCHK=0
while true; do
  process_updates
  check_pulse
  NOW=$(date +%s)
  if [ "$NOW" -ge "$NEXTCHK" ]; then
    do_checks
    NEXTCHK=$((NOW+60))
  fi
done
