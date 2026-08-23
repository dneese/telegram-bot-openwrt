# 🤖 tg-router-bot — Telegram-бот для роутера OpenWrt

[Русский](#русский) · [Українська](#українська) · [English](#english)

Бот поддерживает три языка сообщений: **ru / uk / en**.
Зміна мови: `uci set tgbot.config.lang='uk' && uci commit tgbot` (або в LuCI).
Bot language is configured via `tgbot.config.lang` (ru, uk or en; default ru).

---

## Русский

Лёгкий (~12 КБ) Telegram-бот на чистом shell для управления роутером OpenWrt.
Без Python и зависимостей сверх стандартных. Работает демоном через procd,
отвечает мгновенно (long-polling), есть страница настроек в LuCI.

### Возможности

- **Ежечасный пульс** — бот редактирует одно сообщение с аптаймом;
  время устарело → роутер выключен (heartbeat-мониторинг)
- **Команды**: `/status`, `/devices`, `/wan`, `/reboot yes`, `/qr`, `/scan`,
  `/backup`, `/alias IP Имя`, `/watch add MAC Имя`, `/mon add host`, `/help`
- **🤖 AI-чат** (`/ai вопрос`) — агент на бесплатных моделях OpenRouter видит
  состояние роутера и выполняет команды; изменения настроек — только после
  подтверждения кнопкой. Ответы приходят с rich-форматированием Telegram
  (жирный, курсив, код, цитаты, ссылки), автозакрытием тегов и разбивкой
  длинных ответов на части (лимит 4096)
- **👀 Слежка** — уведомления «дома/ушёл» по MAC телефона
- **👁 Мониторинг хостов** — падение/восстановление по ping
- **Белый список**: команды принимает только ваш Chat ID

### Файлы

| Файл | Куда на роутере | Назначение |
|---|---|---|
| `tg-bot.sh` | `/usr/bin/tg-bot.sh` | Сам бот (демон) |
| `tg-bot.init` | `/etc/init.d/tg-bot` | Автозапуск procd |
| `tgbot.menu.json` | `/usr/share/luci/menu.d/luci-app-tgbot.json` | Пункт меню LuCI |
| `tgbot.acl.json` | `/usr/share/rpcd/acl.d/luci-app-tgbot.json` | Права доступа LuCI |
| `tgbot.settings.js` | `/www/luci-static/resources/view/tgbot/settings.js` | Страница настроек |

### Требования

OpenWrt 21.02+ (проверено на 25.12, ramips/mt7621): `curl`, `jsonfilter`,
`uci`, busybox `awk/sed/grep`. LuCI — опционально.

### Установка

```sh
# 0) @BotFather → /newbot → токен; узнайте свой Chat ID:
curl -s "https://api.telegram.org/bot<ТОКЕН>/getUpdates" | grep -o '"id":[0-9]*' | head -1

# 1) Залейте файлы (см. таблицу выше), например:
scp tg-bot.sh root@192.168.1.1:/usr/bin/tg-bot.sh
scp tg-bot.init root@192.168.1.1:/etc/init.d/tg-bot

# 2) Конфиг
ssh root@192.168.1.1 'cat > /etc/config/tgbot << EOF
config tgbot "config"
	option token "СЮДА_ТОКЕН"
	option chatid "СЮДА_CHAT_ID"
	option lang "ru"
EOF
chmod 600 /etc/config/tgbot'

# 3) Активация
ssh root@192.168.1.1 'chmod +x /usr/bin/tg-bot.sh /etc/init.d/tg-bot
/etc/init.d/tg-bot enable && /etc/init.d/tg-bot start'
```

### Безопасность AI-агента

Опасные команды (`rm -rf`, `mkfs`, `dd`, прошивки) блокируются; всё, что меняет
настройки (`uci`, `apk`, сервисы), требует подтверждения кнопкой ✅.

---

## Українська

Легкий (~12 КБ) Telegram-бот чистою shell-мовою для керування роутером OpenWrt.
Без Python і зайвих залежностей. Працює демоном через procd, відповідає
миттєво (long-polling), є сторінка налаштувань у LuCI.

### Можливості

- **Щогодинний пульс** — бот редагує одне повідомлення з аптаймом;
  час застарів → роутер вимкнено (heartbeat-моніторинг)
- **Команди**: `/status`, `/devices`, `/wan`, `/reboot yes`, `/qr`, `/scan`,
  `/backup`, `/alias IP Назва`, `/watch add MAC Назва`, `/mon add host`, `/help`
- **🤖 AI-чат** (`/ai питання`) — агент на безкоштовних моделях OpenRouter бачить
  стан роутера і виконує команди; зміни налаштувань — лише після підтвердження
  кнопкою. Відповіді з rich-форматуванням Telegram, автозакриттям тегів
  та розбивкою довгих відповідей на частини (ліміт 4096)
- **👀 Слідкування** — повідомлення «вдома/пішов» за MAC телефону
- **👁 Моніторинг хостів** — падіння/відновлення за ping
- **Білий список**: команди приймає лише ваш Chat ID

### Встановлення

Те саме, що й у російському розділі вище (файли, конфіг, активація),
але в конфізі вкажіть `option lang 'uk'`.

---

## English

A lightweight (~12 KB) pure-shell Telegram bot for controlling an OpenWrt router.
No Python, no extra dependencies. Runs as a procd daemon, replies instantly
(long-polling), includes a LuCI settings page.

### Features

- **Hourly heartbeat** — the bot edits a single uptime message;
  stale time = router down (heartbeat monitoring)
- **Commands**: `/status`, `/devices`, `/wan`, `/reboot yes`, `/qr`, `/scan`,
  `/backup`, `/alias IP Name`, `/watch add MAC Name`, `/mon add host`, `/help`
- **🤖 AI chat** (`/ai question`) — an agent on free OpenRouter models sees
  router state and runs commands; config changes require button confirmation.
  Replies use Telegram rich formatting, auto-closed tags, and long answers
  are split into chunks (4096-char API limit)
- **👀 People watching** — home/away notifications by phone MAC
- **👁 Host monitoring** — down/up alerts by ping
- **Allow-list**: only your Chat ID can issue commands

### Installation

Same steps as in the Russian section above (files, config, activation),
but set `option lang 'en'` in the config.

### Security notes

Dangerous commands (`rm -rf`, `mkfs`, `dd`, firmware ops) are blocked;
anything that changes settings (`uci`, `apk`, services) requires explicit
✅ confirmation. Keep your bot token secret; `/etc/config/tgbot` must be
`chmod 600`.
