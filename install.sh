#!/bin/sh
# ============================================================
#  tg-router-bot installer for OpenWrt / ImmortalWrt (apk-based)
#  Запуск НА РОУТЕРІ:  sh install.sh [опції]
#
#  Опції (або інтерактивно спита):
#   --token  BOT_TOKEN      токен від @BotFather
#   --chatid CHAT_ID        ваш Telegram ID
#   --lang   ru|uk|en       мова повідомлень (def: ru)
#   --model  MODEL          AI модель (def: qwen/qwen3.6-27b)
#   --key    API_KEY        ключ AI провайдера (Groq/OpenRouter/Gemini)
#   --url    URL            OpenAI-сумісний endpoint (def: Groq)
#   --uninstall              повне видалення
# ============================================================
SRC="$(cd "$(dirname "$0")" && pwd)"
PREFIX=/usr/bin
DIR=/etc/tg-bot

TOKEN=""; CHATID=""; LANG_=""; MODEL=""; KEY=""; URL=""; UNINST=0
while [ $# -gt 0 ]; do
  case "$1" in
    --token) TOKEN="$2"; shift 2 ;;
    --chatid) CHATID="$2"; shift 2 ;;
    --lang) LANG_="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --key) KEY="$2"; shift 2 ;;
    --url) URL="$2"; shift 2 ;;
    --uninstall) UNINST=1; shift ;;
    *) echo "? невідома опція $1"; shift ;;
  esac
done

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

# --- промпти і скіли ---
mkdir -p $DIR/ai/skills
for F in core.txt recipes.txt facts.md intent.txt topology.md corrections.md; do
  SRCF="$SRC/prompts/$F"
  # не перезаписувати накопичене (corrections/topology) якщо вже є
  { [ "$F" = "corrections.md" ] || [ "$F" = "topology.md" ]; } && [ -s "$DIR/ai/$F" ] && continue
  [ -f "$SRCF" ] && cp "$SRCF" "$DIR/ai/$F"
done
[ -f "$SRC/prompts/intent.txt" ] && cp "$SRC/prompts/intent.txt" "$DIR/ai/intent.txt"
for S in "$SRC"/prompts/skills/*.md; do
  [ -f "$S" ] && cp "$S" "$DIR/ai/skills/$(basename "$S")"
done
touch "$DIR/ai/corrections.md" "$DIR/ai/topology.md"

# --- конфігурація uci ---
if ! uci -q get tgbot.config >/dev/null 2>&1; then
  echo "=== Первинне налаштування ==="
  [ -z "$TOKEN" ] && printf 'Токен від @BotFather: ' && read -r TOKEN
  [ -z "$CHATID" ] && printf 'Ваш Chat ID (число): ' && read -r CHATID
  [ -z "$LANG_" ] && { printf 'Мова [ru/uk/en, def ru]: '; read -r LANG_; }
  [ -z "$KEY" ] && printf 'AI-ключ (gsk_/sk-or-v1/інший; Enter = пропустити, додасте пізніше в LuCI або /key у боті): ' && read -r KEY
  touch /etc/config/tgbot && chown root:root /etc/config/tgbot
  uci set tgbot.config=config 2>/dev/null || uci set tgbot.config='config'
fi
[ -n "$TOKEN" ] && uci set tgbot.config.token="$TOKEN"
[ -n "$CHATID" ] && uci set tgbot.config.chatid="$CHATID"
[ -n "$LANG_" ] && uci set tgbot.config.lang="$LANG_"
# AI-ключ: авто-маршрут за префіксом (та сама логіка що й /key у боті)
case "$KEY" in
  gsk_*)
    [ -z "$URL" ] && URL="https://api.groq.com/openai/v1/chat/completions"
    [ -z "$MODEL" ] && MODEL="qwen/qwen3.6-27b"
    uci set tgbot.config.ai_key="$KEY"; echo "ключ → ai_key (Groq)" ;;
  sk-or-v1*)
    uci set tgbot.config.ai_url2="https://openrouter.ai/api/v1/chat/completions"
    uci set tgbot.config.ai_key2="$KEY"
    [ -z "$(uci -q get tgbot.config.ai_model)" ] && uci set tgbot.config.ai_model="openai/gpt-oss-20b"
    echo "ключ → ai_key2 (OpenRouter)" ;;
  ??*)
    uci set tgbot.config.ai_key3="$KEY"
    uci set tgbot.config.ai_model3="gemini-3.6-flash"
    echo "ключ → ai_key3 (Gemini)" ;;
esac
[ -n "$MODEL" ] && uci set tgbot.config.ai_model="$MODEL"
[ -n "$KEY" ] && uci set tgbot.config.ai_key="$KEY"
[ -n "$URL" ] && uci set tgbot.config.ai_url="$URL"
uci set tgbot.config.ai_model_alt="${AI_ALT:-openai/gpt-oss-20b}"
uci set tgbot.config.ai_url2="https://openrouter.ai/api/v1/chat/completions"
uci commit tgbot
chmod 600 /etc/config/tgbot 2>/dev/null

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
echo " • AI-ключі можна додати ПОЗНІШЕ будь-коли:"
echo "     LuCI → Services → Telegram Bot, АБО просто надішліть боту: /key gsk_ваш_ключ"
echo " • AI: /ai ваше питання   (без ключа AI-режим не запуститься)"
echo " • Лог діалогів: /ailog   Відкат змін: /rollback"
echo " • Мова: uci set tgbot.config.lang=uk|ru|en ; скіли: $DIR/ai/skills/"
