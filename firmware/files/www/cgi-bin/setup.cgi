#!/bin/sh
# ============================================================
# tg-router-bot setup wizard (CGI, busybox sh) — TP-Link 4MB build
# Кроковий майстер: WAN -> WiFi -> Telegram -> Мова -> Застосувати
# Працює локально через uhttpd, інтернет не потрібен.
# ============================================================
export PATH="/usr/sbin:/usr/bin:/sbin:/bin"

STEP="${FORM_step:-1}"
[ -z "$FORM_step" ] && STEP="${QS_step:-1}"
case "$STEP" in ''|*[!0-9]*) STEP=1 ;; esac
[ "$STEP" -ge 6 ] && STEP=5

# --- urldecode ---
udec() {
  printf '%b' "$(printf '%s' "$1" | sed 's/+/ /g; s/%/\\x/g')"
}
# --- парсинг рядка a=1&b=2 -> змінні FORM_<a> ---
parse_kv() {
  printf '%s' "$1" | tr '&' '\n' | while IFS='=' read -r K V; do
    [ -n "$K" ] || continue
    printf '%s\n' "$(udec "$V")"
  done >/dev/null # placeholder
}

# розбираємо QUERY_STRING або POST-тіло у змінні FORM_*
read_form() {
  RAW=""
  if [ "$REQUEST_METHOD" = "POST" ] && [ -n "$CONTENT_LENGTH" ]; then
    RAW=$(dd bs=1 count="$CONTENT_LENGTH" 2>/dev/null)
  else
    RAW="$QUERY_STRING"
  fi
  [ -n "$RAW" ] || return 0
  OLDIFS=$IFS
  IFS='&'
  set -- $RAW
  IFS=$OLDIFS
  for PAIR in "$@"; do
    K=${PAIR%%=*}; V=${PAIR#*=}
    [ "$K" = "$PAIR" ] && V=""
    case "$K" in
      *[!A-Za-z0-9_]*) ;;
      *) eval "FORM_$K=\"\$(printf '%b' \"\$(printf '%s' \"\$V\" | sed 's/+/ /g; s/%/\\\\x/g')\")\"" ;;
    esac
  done
}
read_form

ESC() { printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'; }

page_head() {
  printf 'Content-Type: text/html; charset=utf-8\r\n\r\n'
  cat <<'HTML'
<!DOCTYPE html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>tg-router-bot налаштування</title>
<style>
body{font-family:sans-serif;background:#f4f6f8;margin:0;padding:16px;max-width:520px;margin:auto}
h3{color:#245} .card{background:#fff;border-radius:10px;padding:14px;margin:10px 0;box-shadow:0 1px 4px #0002}
input[type=text],input[type=password],select{width:100%;padding:8px;margin:4px 0 10px;border:1px solid #ccd;border-radius:6px;box-sizing:border-box}
button,.btn{background:#2877c8;color:#fff;border:none;padding:10px 18px;border-radius:6px;font-size:15px;text-decoration:none;display:inline-block}
.ok{color:#186a2c;font-weight:bold} .warn{color:#a33}
table{width:100%;border-collapse:collapse}td{padding:3px 6px;border-bottom:1px solid #eee}
.step{color:#888;font-size:13px}
</style></head><body>
<h3>🤖 tg-router-bot</h3>
HTML
  printf '<div class="step">Крок %s з 5</div>\n' "${FORM_step:-$STEP}"
}
page_foot() { printf '</body></html>'; }
nav() { printf '<form method="POST"><input type="hidden" name="step" value="%s">' "$1"; }
endform() { printf '<button>%s</button></form>' "$1"; }
field() { # $1=name $2=label $3=value [$4=password]
  printf '<label>%s</label>' "$(esc "$2")"
  T=text; [ "$4" = "pw" ] && T=password
  printf '<input type="%s" name="%s" value="%s">' "$T" "$1" "$(esc "$3")"
}

uci_get() { uci -q get "$1" 2>/dev/null; }
# ===== ПРОШИВКА: завантаження файлу (raw body через JS fetch) =====
if [ "${FORM_fwupload:-}" = "1" ] && [ "$REQUEST_METHOD" = "POST" ] && [ -n "$CONTENT_LENGTH" ]; then
  printf 'Content-Type: text/plain\r\n\r\n'
  rm -f /tmp/fw.bin /tmp/fw.err
  BS=65536
  CNT=$(( (CONTENT_LENGTH + BS - 1) / BS ))
  dd of=/tmp/fw.bin bs=$BS count=$CNT 2>/dev/null
  SZ=$(wc -c < /tmp/fw.bin 2>/dev/null)
  if [ "${SZ:-0}" -ge 2097152 ]; then
    sync
    echo "OK ${SZ} bytes — записую, роутер перезавантажиться сам (~2 хв)"
    ( sleep 3; sysupgrade -v /tmp/fw.bin >/tmp/fw.log 2>&1; sleep 10; reboot ) >/dev/null 2>&1 &
  else
    echo "FAIL ${SZ:-0} bytes — файл не схожий на прошивку (менше 2МБ), запис СКАСОВАНО"
  fi
  exit 0
fi

# ===== ПРОШИВКА: завантаження за URL =====
if [ "${FORM_fw_flash:-}" = "1" ] && [ -n "${FORM_fw_url:-}" ]; then
  printf 'Content-Type: text/html; charset=utf-8\r\n\r\n'
  cat <<'HTML'
<!DOCTYPE html><html><head><meta charset="utf-8"></head><body style="font-family:sans-serif">
<h3>⏳ Завантажую прошивку за URL…</h3>
<p class="warn">НЕ ВИМИКАЙТЕ ЖИВЛЕННЯ! Після запису роутер перезавантажиться сам (~2 хв).</p>
</body></html>
HTML
  (
    rm -f /tmp/fw.bin /tmp/fw.err
    curl -s --max-time 600 -o /tmp/fw.bin "${FORM_fw_url}"
    SZ=$(wc -c < /tmp/fw.bin 2>/dev/null)
    if [ "${SZ:-0}" -ge 2097152 ]; then
      sync
      sysupgrade -v /tmp/fw.bin >/tmp/fw.log 2>&1
      sleep 10; reboot
    else
      echo "$(date '+%d.%m %H:%M') FAIL size=${SZ:-0} url=${FORM_fw_url}" > /tmp/fw.err
    fi
  ) >/dev/null 2>&1 &
  exit 0
fi

# ===== STATUS =====
if [ "${FORM_status:-}" = "1" ] || [ "$QUERY_STRING" = "status=1" ]; then
  page_head
  RUN="<span class='warn'>❌ не запущений</span>"
  pgrep -f 'tg-bot.sh' >/dev/null && RUN="<span class='ok'>✅ працює</span>"
  INT=$(ping -c1 -W3 1.1.1.1 >/dev/null 2>&1 && echo "<span class='ok'>✅ є</span>" || echo "<span class='warn'>немає</span>")
  echo "<div class='card'><h3>📊 Статус</h3><table>"
  printf '%s' "<tr><td>Сервіс бота</td><td>$RUN</td></tr>"
  printf '%s' "<tr><td>Інтернет</td><td>$INT</td></tr>"
  printf '%s' "<tr><td>WAN IP</td><td>$(ip addr show wan 2>/dev/null | awk '/inet /{print $2}') </td></tr>"
  echo '</table>'
  printf '%s' '<p><a class="btn" href="?step=1">Майстер знову</a> '
  printf "%s" "<form method=\"POST\" style=\"display:inline\"><input type=\"hidden\" name=\"reboot_r\" value=\"1\"><button onclick=\"return confirm('Перезавантажити роутер?')\">🔄 Ребут</button></form></p>"
  ERR=""
  [ -f /tmp/fw.err ] && ERR=$(tail -n 1 /tmp/fw.err)
  cat <<'HTML'
<div class="card"><h3>⚙️ Прошивка</h3>
<p>Завантажте файл <b>sysupgrade.bin</b> з артефактів GitHub Actions (сторінка білда).</p>
<p><input type="file" id="fwfile" accept=".bin">
<button onclick="return fwup()">📥 Завантажити і прошити</button></p>
<p id="fp" class="step"></p>
<p>або завантажити за URL:</p>
<form method="POST">
<input type="hidden" name="fw_flash" value="1">
<input type="text" name="fw_url" placeholder="https://…/sysupgrade.bin" style="width:80%">
<button onclick="return confirm('Прошити за URL? НЕ вимикайте живлення!')">🔗 Прошити</button>
</form>
<script>
async function fwup(){
 var f=document.getElementById("fwfile").files[0];
 if(!f){alert("Виберіть файл прошивки");return false;}
 if(!confirm("Прошити "+f.name+" ("+f.size+" байт)?\\nНЕ вимикайте живлення!"))return false;
 document.getElementById("fp").textContent="Передаю файл…";
 try{
  await fetch("/cgi-bin/setup.cgi?fwupload=1",{method:"POST",body:f});
  document.getElementById("fp").textContent="Записую… роутер перезавантажиться сам (~2 хв). Оновіть сторінку після перезавантаження.";
 }catch(e){document.getElementById("fp").textContent="Помилка передачі: "+e;}
 return false;
}
</script>
</div>
HTML
  [ -f /tmp/fw.err ] && printf '<p class="warn">Попередня спроба: %s</p>' "$(esc "$(tail -n 1 /tmp/fw.err)")"
  echo '</div>'
  page_foot
  exit 0
fi

# ребут підтверджений
if [ "${FORM_reboot_r:-}" = "1" ]; then
  page_head
  echo '<div class="card"><h3>🔄 Перезавантажуюсь…</h3><p>Сторінка оживе після буту.</p></div>'
  page_foot
  sleep 2; reboot
  exit 0
fi

uci_get() { uci -q get "$1" 2>/dev/null; }
# ================= СТОРІНКИ =================
if [ "$STEP" = "1" ]; then
  page_head
  PROTO=$(uci_get network.wan.proto); PROTO=${PROTO:-dhcp}
  nav 11
  echo '<div class="card"><h3>Крок 1: Інтернет (WAN)</h3>'
  P=""; [ "$PROTO" = "pppoe" ] && P=" checked"
  S=""; [ "$PROTO" = "static" ] && S=" checked"
  D=""; [ "$PROTO" != "pppoe" ] && [ "$PROTO" != "static" ] && D=" checked"
  printf '%s' "<label><input type=radio name=wan_proto value=dhcp$D> DHCP — автоматично (рекомендовано)</label><br>"
  printf '%s' "<label><input type=radio name=wan_proto value=pppoe$P> PPPoE — логін/пароль провайдера</label>"
  field wan_user 'PPPoE логін' "$(uci_get network.wan.username)"
  field wan_pass 'PPPoE пароль' "$(uci_get network.wan.password)" pw
  printf '%s' "<label><input type=radio name=wan_proto value=static$S> Статичний IP</label>"
  field wan_ip 'IP адреса' "$(uci_get network.wan.ipaddr)"
  field wan_nm 'Маска' "${STATIC_NM:-255.255.255.0}"
  field wan_gw 'Шлюз' "$(uci_get network.wan.gateway)"
  field wan_dns 'DNS (через кому)' "$(uci_get network.wan.dns)"
  endform 'Далі → WiFi'
  echo '</div>'
  page_foot
  exit 0
fi
if [ "$STEP" = "11" ]; then
  P=${FORM_wan_proto:-dhcp}
  uci -q delete network.wan.username network.wan.password network.wan.ipaddr network.wan.netmask network.wan.gateway network.wan.dns 2>/dev/null
  case "$P" in
    pppoe)
      uci set network.wan.proto='pppoe'
      uci set network.wan.username="${FORM_wan_user}"
      uci set network.wan.password="${FORM_wan_pass}" ;;
    static)
      uci set network.wan.proto='static'
      uci set network.wan.ipaddr="${FORM_wan_ip}"
      uci set network.wan.netmask="${FORM_wan_nm:-255.255.255.0}"
      uci set network.wan.gateway="${FORM_wan_gw}"
      [ -n "${FORM_wan_dns}" ] && uci add_list network.wan.dns="${FORM_wan_dns}" ;;
    *) uci set network.wan.proto='dhcp' ;;
  esac
  uci commit network
  printf 'Location: /cgi-bin/setup.cgi?step=2\r\n\r\n'; exit 0
fi
if [ "$STEP" = "2" ]; then
  page_head
  SS=$(uci_get wireless.@wifi-iface[0].ssid)
  nav 21
  echo '<div class="card"><h3>Крок 2: WiFi точка доступу</h3>'
  field wifi_ssid 'Назва мережі (SSID)' "${FORM_wifi_ssid:-$SS}"
  field wifi_key 'Пароль (мін. 8 символів)' "" pw
  echo '<p class="warn">Залишіть пароль порожнім = відкрита мережа (не радимо).</p>'
  endform 'Далі → Telegram'
  echo '</div>'
  page_foot
  exit 0
fi
if [ "$STEP" = "21" ]; then
  SS=${FORM_wifi_ssid:-tgbot-setup}
  i=0
  while :; do
    uci -q get wireless.@wifi-iface[$i] >/dev/null 2>&1 || break
    uci set wireless.@wifi-iface[$i].ssid="$SS"
    if [ ${#FORM_wifi_key} -ge 8 ]; then
      uci set wireless.@wifi-iface[$i].encryption='psk2'
      uci set wireless.@wifi-iface[$i].key="$FORM_wifi_key"
    else
      uci set wireless.@wifi-iface[$i].encryption='none'
      uci -q delete wireless.@wifi-iface[$i].key
    fi
    i=$((i+1))
  done
  uci commit wireless
  printf 'Location: /cgi-bin/setup.cgi?step=3\r\n\r\n'; exit 0
fi
if [ "$STEP" = "3" ]; then
  page_head
  TK=$(uci_get tgbot.config.token)
  MASKED=""; [ -n "$TK" ] && MASKED="$(printf '%s' "$TK" | sed 's/^\(....\).*\(....\)$/\1…\2/')"
  nav 31
  echo '<div class="card"><h3>Крок 3: Telegram бот</h3>'
  field bot_token "Токен від @BotFather ${MASKED:+(зараз: $MASKED)}" ""
  field bot_chatid 'Ваш Chat ID (число)' "$(uci_get tgbot.config.chatid)"
  echo '<p class="step">Отримати: t.me/BotFather → /newbot; Chat ID: написати боту і дивитись getUpdates.</p>'
  endform 'Далі → Мова'
  echo '</div>'
  page_foot
  exit 0
fi
if [ "$STEP" = "31" ]; then
  [ -n "${FORM_bot_token}" ] && uci set tgbot.config.token="${FORM_bot_token}"
  [ -n "${FORM_bot_chatid}" ] && uci set tgbot.config.chatid="${FORM_bot_chatid}"
  uci commit tgbot
  printf 'Location: /cgi-bin/setup.cgi?step=4\r\n\r\n'; exit 0
fi
if [ "$STEP" = "4" ]; then
  page_head
  L=$(uci_get tgbot.config.lang); L=${L:-uk}
  nav 41
  echo '<div class="card"><h3>Крок 4: Мова бота</h3><select name="lang">'
  for LL in uk ru en; do
    SL=""; [ "$LL" = "$L" ] && SL=" selected"
    printf '%s' "<option value=$LL$SL>$LL</option>"
  done
  echo '</select>'
  endform 'Далі → Підсумок'
  echo '</div>'
  page_foot
  exit 0
fi
if [ "$STEP" = "41" ]; then
  [ -n "${FORM_lang}" ] && uci set tgbot.config.lang="${FORM_lang}"
  uci commit tgbot
  printf 'Location: /cgi-bin/setup.cgi?step=5\r\n\r\n'; exit 0
fi
# ===== КРОК 5: підсумок + застосувати =====
if [ "$STEP" = "5" ]; then
  page_head
  TK=$(uci_get tgbot.config.token)
  CH=$(uci_get tgbot.config.chatid)
  SS=$(uci_get wireless.@wifi-iface[0].ssid)
  WP=$(uci_get network.wan.proto); WP=${WP:-dhcp}
  echo '<div class="card"><h3>Крок 5: Перевірте і застосуйте</h3><table>'
  printf '%s' "<tr><td>WAN</td><td>$WP</td></tr>"
  printf '%s' "<tr><td>WiFi SSID</td><td>$(esc "$SS")</td></tr>"
  [ -n "$TK" ] && TOKS="✅ вказано" || TOKS='<span class="warn">❌ НЕ вказано!</span>'
  printf '%s' "<tr><td>Токен бота</td><td>$TOKS</td></tr>"
  [ -n "$CH" ] && CHS="✅ $CH" || CHS='<span class="warn">❌ НЕ вказано!</span>'
  printf '%s' "<tr><td>Chat ID</td><td>$CHS</td></tr>"
  echo '</table>'
  if [ -z "$TK" ] || [ -z "$CH" ]; then
    echo '<p class="warn">Без токена/chat ID бот не підключиться до Telegram.</p>'
  fi
  printf '%s' '<form method="POST"><input type="hidden" name="apply" value="1"><button>✅ Застосувати і перезапустити</button></form>'
  echo '</div>'
  page_foot
  exit 0
fi
# ===== APPLY =====
if [ "${FORM_apply:-}" = "1" ]; then
  uci commit network 2>/dev/null
  uci commit wireless 2>/dev/null
  uci commit tgbot 2>/dev/null
  (/etc/init.d/network restart >/dev/null 2>&1 \
    && /etc/init.d/dnsmasq restart >/dev/null 2>&1 \
    && /etc/init.d/tg-bot restart >/dev/null 2>&1) &
  page_head
  echo '<div class="card"><h3>⏳ Застосовую…</h3>'
  echo '<p>Мережа перезапускається (~20 с). Якщо змінили WiFi — перепідключіться до нової мережі та оновіть сторінку.</p>'
  echo '<p><a class="btn" href="?status=1">Оновити / статус</a></p></div>'
  page_foot
  exit 0
fi
