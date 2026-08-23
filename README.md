# 🤖 tg-router-bot — Telegram-бот для роутера OpenWrt

Лёгкий (~9 КБ) Telegram-бот на чистом shell для управления роутером OpenWrt.
Без Python, без зависимостей сверх стандартных. Работает как демон через procd,
отвечает мгновенно (long-polling), имеет страницу настроек в LuCI.

## Возможности

- **Ежечасный пульс** — бот редактирует одно и то же сообщение с аптаймом.
  Время устарело → роутер выключен (heartbeat-мониторинг).
- **Команды** (ответ ~1 сек):
  - `/status` — аптайм, нагрузка, RAM, WAN IP, публичный IP, интернет
  - `/devices` — устройства сети (🟢 в сети / ⚪️ не в сети)
  - `/wan` — переподключить интернет-интерфейс
  - `/reboot yes` — перезагрузка с подтверждением
  - `/help` — справка
- **Inline-кнопки** под сообщениями (статус / устройства / WAN / ребут)
- **Страница настроек в LuCI**: Services → Telegram Bot (токен, Chat ID,
  кнопка перезапуска)
- **Белый список**: команды выполняются только от вашего Chat ID —
  знание токена не даёт чужаку управления

## Файлы

| Файл | Куда на роутере | Назначение |
|---|---|---|
| `tg-bot.sh` | `/usr/bin/tg-bot.sh` | Сам бот (демон) |
| `tg-bot.init` | `/etc/init.d/tg-bot` | Автозапуск procd |
| `tgbot.menu.json` | `/usr/share/luci/menu.d/luci-app-tgbot.json` | Пункт меню LuCI |
| `tgbot.acl.json` | `/usr/share/rpcd/acl.d/luci-app-tgbot.json` | Права доступа LuCI |
| `tgbot.settings.js` | `/www/luci-static/resources/view/tgbot/settings.js` | Страница настроек |

## Требования

OpenWrt 21.02+ (проверено на 25.12, ramips/mt7621) со стандартными пакетами:
`curl`, `jsonfilter`, `uci`, busybox `awk/sed/crontab`. LuCI — опционально.

## Установка

### Шаг 0. Получите токен и свой Chat ID

1. В Telegram: @BotFather → `/newbot` → сохраните токен (`123456:ABC-...`)
2. Напишите своему боту любое сообщение (нажмите Start)
3. Узнайте свой Chat ID:
   ```sh
   curl -s "https://api.telegram.org/bot<ТОКЕН>/getUpdates" | grep -o '"id":[0-9]*' | head -1
   ```

### Шаг 1. Залейте файлы на роутер (с компьютера по SSH)

```sh
scp tg-bot.sh root@192.168.1.1:/usr/bin/tg-bot.sh
scp tg-bot.init root@192.168.1.1:/etc/init.d/tg-bot
scp tgbot.menu.json root@192.168.1.1:/usr/share/luci/menu.d/luci-app-tgbot.json
scp tgbot.acl.json root@192.168.1.1:/usr/share/rpcd/acl.d/luci-app-tgbot.json
ssh root@192.168.1.1 "mkdir -p /www/luci-static/resources/view/tgbot"
scp tgbot.settings.js root@192.168.1.1:/www/luci-static/resources/view/tgbot/settings.js
```

### Шаг 2. Создайте конфиг на роутере

```sh
ssh root@192.168.1.1
cat > /etc/config/tgbot << 'EOF'
config tgbot 'config'
	option token 'СЮДА_ТОКЕН'
	option chatid 'СЮДА_CHAT_ID'
EOF
chmod 600 /etc/config/tgbot
```

### Шаг 3. Активируйте

```sh
chmod +x /usr/bin/tg-bot.sh /etc/init.d/tg-bot
/etc/init.d/rpcd restart          # подхватить ACL LuCI
/etc/init.d/uhttpd restart        # подхватить страницу LuCI
/etc/init.d/tg-bot enable         # автозапуск при загрузке
/etc/init.d/tg-bot start          # запустить сейчас
```

### Шаг 4. Проверьте

- В Telegram отправьте боту `/status` — ответ придёт мгновенно
- В LuCI обновите страницу → Services → Telegram Bot

## Как это работает

- Демон крутит long-polling `getUpdates` (timeout 25 c) — реакция ~1 сек
- Настройки читаются из UCI (`tgbot.config.token/chatid`) при старте;
  пустой конфиг → бот молча не работает
- `message_id` пульса хранится в `/etc/tg-bot/msgid` — сообщение
  редактируется повторно даже после перезагрузки роутера
- Offset апдейтов хранится в `/etc/tg-bot/offset` — команды не дублируются
- Ошибки отправки пишутся в `/etc/tg-bot/lasterr`

## Безопасность

- Выполнять команды может только владелец `chatid` из конфига.
  Токен без вашего Chat ID бесполезен для управления, но позволяет читать
  переписку бота — **держите токен в секрете**, при утечке смените через
  @BotFather (`/revoke`) и обновите в LuCI.
- Конфиг `/etc/config/tgbot` должен быть `chmod 600`.

## Устранение неполадок

```sh
pgrep -f tg-bot.sh                  # жив ли демон
cat /etc/tg-bot/lasterr             # последняя ошибка Telegram API
/etc/init.d/tg-bot restart          # перезапуск
logread | grep tg-bot               # системный лог
```

Если команда «молчит» — чаще всего невалидный UTF-8 или HTML-символы
(`<>&`) в имени устройства; последние версии экранируют их автоматически.
