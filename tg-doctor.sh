#!/bin/sh
# ============================================================
#  tg-doctor.sh — самозахист роутера (boot guard + авто-ремонт).
#  Народився з інциденту 24.08: hotplug з "nft flush table" витер
#  fw4 при завантаженні -> інтернет зник до ручного втручання.
#
#  Запускається hotplug'ом при ifup wan. Один прогін на завантаження.
#  Перевіряє: default route / dnsmasq живий / masquerade у fw4.
#  Ремонтує: restart dnsmasq / firewall. Повідомляє власника в TG.
# ============================================================

DIR=/etc/tg-bot
MARK="$DIR/.doctor_boot"

notify() {
  WTT=$(uci -q get tgbot.config.token); WCCH=$(uci -q get tgbot.config.chatid)
  [ -z "$WTT" ] || [ -z "$WCCH" ] && return 0
  curl -s --max-time 10 -H "Content-Type: application/json" \
    -d "{\"chat_id\":\"$WCCH\",\"text\":\"$(printf '%s' "$1" | sed 's/"/\\"/g' | tr '\n' ' ')\"}" \
    "https://api.telegram.org/bot$WTT/sendMessage" >/dev/null 2>&1
}

# один прогін на завантаження (ідентифікатор бута)
BOOTID=$(cut -c1-8 /proc/sys/kernel/random/boot_id 2>/dev/null)
[ -z "$BOOTID" ] && exit 0
[ "$BOOTID" = "$(cat "$MARK" 2>/dev/null)" ] && exit 0
echo "$BOOTID" > "$MARK"
mkdir -p "$DIR"

FIX=""

# 1) default route присутній?
ip route show default 2>/dev/null | grep -q . || FIX="$FIX • нема default route;"

# 2) dnsmasq живий?
if ! pgrep dnsmasq >/dev/null 2>&1; then
  /etc/init.d/dnsmasq restart >/dev/null 2>&1
  sleep 3
  pgrep dnsmasq >/dev/null 2>&1 && FIX="$FIX • перезапущено dnsmasq;" || FIX="$FIX • dnsmasq НЕ ВСТАВ;"
fi

# 3) masquerade присутній у fw4? (його втрата = LAN без інтернету)
if command -v nft >/dev/null 2>&1; then
  if ! nft list ruleset 2>/dev/null | grep -qiE 'masquerade'; then
    /etc/init.d/firewall restart >/dev/null 2>&1
    sleep 5
    nft list ruleset 2>/dev/null | grep -qiE 'masquerade' \
      && FIX="$FIX • відновлено файрвол (masq);" \
      || FIX="$FIX • masq НЕ ЗНАЙДЕНО навіть після rebuild;"
  fi
fi

# 4) WAN реально працює? (спроба після можливих ремонтів вище)
sleep 2
ping -c1 -W3 1.1.1.1 >/dev/null 2>&1 || FIX="$FIX • WAN не пінгується;"

if [ -n "$FIX" ]; then
  logger -t tg-doctor "REPAIRED:$FIX"
  notify "🩺 tg-doctor: авто-ремонт після буту:$FIX"
else
  logger -t tg-doctor "check ok"
fi
