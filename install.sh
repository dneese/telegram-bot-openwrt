#!/bin/sh
# ============================================================
#  tg-router-bot installer for OpenWrt / ImmortalWrt (apk-based)
#  Запуск НА РОУТЕРІ:  sh install.sh [опції]
#
#  Опції (або інтерактивно спита):
#   --token  BOT_TOKEN      токен від @BotFather
#   --chatid CHAT_ID        ваш Telegram ID
#   --lang   ru|uk|en|all   мова повідомлень (def: ru, all=всі 3)
#   --modules LIST           модулі через кому: wifi,warp,firewall,diag,system,watch,alias,mon (def: all)
#   --minimal                пресет light: wifi,warp,status,qr,scan,backup (без firewall/diag/system)
#   --uninstall              повне видалення
# ============================================================
SRC="$(cd "$(dirname "$0")" && pwd)"
PREFIX=/usr/bin
DIR=/etc/tg-bot

TOKEN=""; CHATID=""; LANG_=""; MODS=""; UNINST=0
while [ $# -gt 0 ]; do
  case "$1" in
    --token) TOKEN="$2"; shift 2 ;;
    --chatid) CHATID="$2"; shift 2 ;;
    --lang) LANG_="$2"; shift 2 ;;
    --modules) MODS="$2"; shift 2 ;;
    --minimal) MODS="wifi,warp"; shift ;;
    --uninstall) UNINST=1; shift ;;
    *) echo "? невідома опція $1"; shift ;;
  esac
done
[ -z "$MODS" ] && MODS="all"
# LANG_ залишаємо порожнім для інтерактивного запиту нижче; фільтр мови застосується після визначення

if [ "$UNINST" = "1" ]; then
  echo "== Видалення tg-router-bot =="
  /etc/init.d/tg-bot stop 2>/dev/null
  /etc/init.d/tg-bot disable 2>/dev/null
  /etc/init.d/tg-watch stop 2>/dev/null
  /etc/init.d/tg-watch disable 2>/dev/null
  rm -f $PREFIX/tg-bot.sh $PREFIX/tg-analyze.sh $PREFIX/tg-watch.sh $PREFIX/tg-doctor.sh
  rm -f /etc/init.d/tg-bot /etc/init.d/tg-watch
  rm -f /etc/hotplug.d/iface/99-tg-doctor
  rm -f /www/luci-static/resources/view/tgbot/settings.js
  rm -f /usr/share/luci/menu.d/luci-app-tgbot.json
  rm -f /usr/share/rpcd/acl.d/luci-app-tgbot.json
  crontab -l 2>/dev/null | grep -v tg-analyze | crontab -
  echo "Конфіги та дані лишені у /etc/config/tgbot та $DIR (видаліть вручну за потреби)."
  exit 0
fi

echo "== tg-router-bot installer =="
echo "⚠️  ЕКСПЕРИМЕНТАЛЬНИЙ ПРОЄКТ: не рекомендується для робочих/відповідальних роутерів."

# --- залежності ---
MISS=""
command -v curl >/dev/null || MISS="$MISS curl"
command -v jsonfilter >/dev/null || MISS="$MISS jsonfilter"
[ -n "$MISS" ] && { echo "Встановлюю залежности:$MISS"; apk update >/dev/null 2>&1; apk add $MISS || exit 1; }

# --- бекап попередніх версій ---
TS=$(date +%Y%m%d-%H%M%S)
for F in $PREFIX/tg-bot.sh $PREFIX/tg-watch.sh /etc/init.d/tg-bot /etc/init.d/tg-watch; do
  [ -f "$F" ] && cp "$F" "$F.bak.$TS" && echo "backup: $F -> $F.bak.$TS"
done

# --- файли бота ---
cp "$SRC/tg-bot.sh" $PREFIX/tg-bot.sh && chmod +x $PREFIX/tg-bot.sh
[ -f "$SRC/tg-analyze.sh" ] && cp "$SRC/tg-analyze.sh" $PREFIX/tg-analyze.sh && chmod +x $PREFIX/tg-analyze.sh
[ -f "$SRC/tg-watch.sh" ] && cp "$SRC/tg-watch.sh" $PREFIX/tg-watch.sh && chmod +x $PREFIX/tg-watch.sh
[ -f "$SRC/tg-doctor.sh" ] && cp "$SRC/tg-doctor.sh" $PREFIX/tg-doctor.sh && chmod +x $PREFIX/tg-doctor.sh
[ -f "$SRC/tg-doctor.hotplug" ] && { mkdir -p /etc/hotplug.d/iface; cp "$SRC/tg-doctor.hotplug" /etc/hotplug.d/iface/99-tg-doctor; chmod 644 /etc/hotplug.d/iface/99-tg-doctor; }
[ -f "$SRC/tg-watch.init" ] && cp "$SRC/tg-watch.init" /etc/init.d/tg-watch && chmod +x /etc/init.d/tg-watch
[ -f "$SRC/tg-bot.init" ] && cp "$SRC/tg-bot.init" /etc/init.d/tg-bot && chmod +x /etc/init.d/tg-bot
[ -f "$SRC/tgbot.menu.json" ] && { mkdir -p /usr/share/luci/menu.d; cp "$SRC/tgbot.menu.json" /usr/share/luci/menu.d/luci-app-tgbot.json; }
[ -f "$SRC/tgbot.acl.json" ] && { mkdir -p /usr/share/rpcd/acl.d; cp "$SRC/tgbot.acl.json" /usr/share/rpcd/acl.d/luci-app-tgbot.json; }
[ -f "$SRC/tgbot.settings.js" ] && { mkdir -p /www/luci-static/resources/view/tgbot; cp "$SRC/tgbot.settings.js" /www/luci-static/resources/view/tgbot/settings.js && chmod 644 /www/luci-static/resources/view/tgbot/settings.js; }
chmod 644 /usr/share/luci/menu.d/luci-app-tgbot.json /usr/share/rpcd/acl.d/luci-app-tgbot.json 2>/dev/null

# --- light: промпти AI не потрібні ---
mkdir -p $DIR

# --- конфігурація uci ---
if ! uci -q get tgbot.config >/dev/null 2>&1; then
  echo "=== Первинне налаштування ==="
  [ -z "$TOKEN" ] && printf 'Токен від @BotFather: ' && read -r TOKEN
  [ -z "$CHATID" ] && printf 'Ваш Chat ID (число): ' && read -r CHATID
  [ -z "$LANG_" ] && { printf 'Мова [ru/uk/en, def ru]: '; read -r LANG_; }
  touch /etc/config/tgbot && chown root:root /etc/config/tgbot
  uci set tgbot.config=config 2>/dev/null || uci set tgbot.config='config'
fi
[ -n "$TOKEN" ] && uci set tgbot.config.token="$TOKEN"
[ -n "$CHATID" ] && uci set tgbot.config.chatid="$CHATID"
[ -n "$LANG_" ] && uci set tgbot.config.lang="$LANG_"
uci commit tgbot
chmod 600 /etc/config/tgbot 2>/dev/null
# --- оптимізація розміру: фільтр мови та модулів (після визначення LANG) ---
if [ -n "$LANG_" ] && [ "$LANG_" != "all" ]; then
  echo "✂️  Фільтр мови: $LANG_ (було ru+uk+en)"
  TMPF="$PREFIX/tg-bot.sh.tmp"
  : > "$TMPF"
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      T_*)
        # витягаємо кожне присвоєння T_...='...' (враховує ; всередині лапок)
        keep=$(printf '%s\n' "$line" | grep -o "T_[^=]*='[^']*'" | grep "_${LANG_}=" | paste -sd "; " -)
        [ -n "$keep" ] && printf '%s\n' "$keep" >> "$TMPF" || true
        ;;
      *) printf '%s\n' "$line" >> "$TMPF" ;;
    esac
  done < "$PREFIX/tg-bot.sh"
  mv "$TMPF" "$PREFIX/tg-bot.sh"
  echo "   $(wc -c < "$PREFIX/tg-bot.sh") bytes після фільтру мови"
fi
if [ "$MODS" != "all" ]; then
  echo "✂️  Фільтр модулів: $MODS"
  case ",$MODS," in *",firewall,"*) ;; *) sed -i '/^# --- Фаєрвол/,/^# --- Діагностика/c\# --- Фаєрвол: вимкнено (install --modules)\nfw_redirects(){ return 1; }\nfw_kb(){ return 1; }\nfw_confirm(){ return 1; }' "$PREFIX/tg-bot.sh" 2>/dev/null || true ;; esac
  case ",$MODS," in *",diag,"*) ;; *) sed -i '/^# --- Діагностика/,/^# --- Система/c\# --- Діагностика: вимкнено\n' "$PREFIX/tg-bot.sh" 2>/dev/null || true ;; esac
fi
sh -n "$PREFIX/tg-bot.sh" 2>/dev/null || { echo "❌ tg-bot.sh синтаксис зламався після фільтру"; exit 1; }

# --- cron для аналізатора ---
if [ -x $PREFIX/tg-analyze.sh ]; then
  CR=$(crontab -l 2>/dev/null | grep -v tg-analyze; echo "0 * * * * $PREFIX/tg-analyze.sh")
  echo "$CR" | crontab -
  echo "cron: аналізатор здоровʼя щогодини"
fi

# --- запуск ---
/etc/init.d/tg-bot enable 2>/dev/null
/etc/init.d/tg-bot restart 2>/dev/null || /etc/init.d/tg-bot start
if [ -f /etc/init.d/tg-watch ]; then
  /etc/init.d/tg-watch enable 2>/dev/null
  /etc/init.d/tg-watch restart 2>/dev/null || /etc/init.d/tg-watch start
fi
sleep 4

echo ""
echo "== Статус =="
pgrep -f "$PREFIX/tg-bot.sh" >/dev/null && echo "✅ процес працює" || echo "❌ ПРОЦЕС НЕ ЗАПУСТИВСЯ (див. logread | grep tg-bot)"
pgrep -f "$PREFIX/tg-watch.sh" >/dev/null && echo "✅ вотчер подій працює (тихий режим: uci set tgbot.config.watch_quiet=1)" || echo "⚠️ вотчер не запустився (не критично)"
TT=$(uci -q get tgbot.config.token)
[ -n "$TT" ] && curl -s --max-time 10 "https://api.telegram.org/bot$TT/getMe" | grep -q '"ok":true' \
  && echo "✅ Telegram API доступний" || echo "⚠️ Telegram API недоступний (перевірте токен/інтернет)"

echo ""
echo "Готово. Далі:"
echo " • Напишіть боту /status"
echo " • Меню: /start  Wi-Fi: /wifi  Статус: /status"
echo " • Відкат змін: /rollback"
echo " • Мова: uci set tgbot.config.lang=uk|ru|en"
