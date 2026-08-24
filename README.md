# 🤖 tg-router-bot — AI-адміністратор роутера OpenWrt у Telegram

[Русский](#русский) · [Українська](#українська) · [English](#english)

> [!WARNING]
> **Експериментальний проєкт.** Це хобі-бот: AI самостійно формує і виконує команди на роутері (`uci`, сервіси, файрвол). Хоча є підтвердження змін, diff-preview, страховка DMS і `/rollback`, проєкт **не рекомендується для відповідальних/робочих роутерів** — тримайте його на домашньому залізі або тестовому девайсі.
>
> **Experimental project.** The bot builds and executes router commands autonomously via AI. Confirm-gates, DMS auto-rollback and `/rollback` exist, but this is hobby software — **do not install on production routers**.
>
> **Экспериментальный проект.** Бот самостоятельно формирует и выполняет команды на роутере через AI. Подтверждения и откат есть, но для боевых роутеров установка **не рекомендуется**.

Кишеньковий системний адміністратор: пишеш боту людською мовою — він сам діагностує, налаштовує та перевіряє роутер через `uci/ubus/iwinfo/apk`.

**Мови бота:** ru / uk / en · **AI:** будь-який OpenAI-сумісний провайдер (Groq, Google Gemini, OpenRouter) з автоматичним фолбеком між моделями.

---

## Русский

Лёгкий shell-бот (~14 КБ, busybox-only) для ImmortalWrt/OpenWrt 24.x+ (apk). Без Python/Node.

### Возможности

- **🤖 AI-агент**: «зроби гостьовий wifi», «хто найбільше качає», «встанови DNS Google» — агент сам виконує команди і звітує. Знання розкладено по **скілах** (`wifi.md`, `dns.md`, `firewall.md`, `vpn.md`, …)
- **Швидкі дії без токенів**: типові питання (пристрої/скан/стан) йдуть через intent-класифікатор (~250 токенів замість ~3000)
- **Rich-таблиці** (Bot API 10.x): пристрої, скан ефіру, статус — справжні таблиці Telegram
- **Безпека**: підтвердження кнопкою на зміни, diff preview (`uci changes`), авто-дописування `commit`, маскування паролів у відповідях, блок rm -rf/mkfs/dd/sysupgrade
- **Захист у глибину**: `sanitize_cmd()` відхиляє підстановки `$()`/`` ` ``/`${}`, `;`-ланцюжки, одиночний `&`, керуючі байти та zero-width/RTL-спуф у командах від моделі (ідея: [oasis security_guard](https://github.com/utakamo/oasis))
- **⚙️ /model**: зміна основної AI-моделі прямо з чату кнопкою — застосовується одразу, без рестарту і SSH
- **🌐 tg-watch** (live-push): нова DHCP-аренда чи падіння порту — миттєве повідомлення в чат (`logread -f`, дедуп 10 хв + rate-limit; тихий режим: `uci set tgbot.config.watch_quiet=1`)
- **🔒 Страхівка (DMS)**: мережеві зміни можна виконати «зі страховкою» — 90 с на сигнал життя, інакше авто-відкат конфігів; або `/rollback` вручну
- **Пульс щогодини**, 👀 слежка за людьми по MAC, 👁 моніторинг хостів
- **Самонавчання**: ваші виправлення потрапляють у `corrections.md` і завжди враховуються; факти про роутер — у `facts.md`; топологія — `/topo`
- 🧾 `/ailog` — повний журнал діалогів файлом

### Установка (одна команда)

```sh
# 0) @BotFather → /newbot → токен; свій ID:
curl -s "https://api.telegram.org/bot<TOKEN>/getUpdates" | grep -o '"id":[0-9]*' | head -1

# 1) На роутері (завантажить усі файли з GitHub і запустить інсталятор):
wget -O - https://raw.githubusercontent.com/dneese/telegram-bot-openwrt/master/tg-installer.sh | sh \
  -s -- --token '123456:ABC' --chatid ВАШ_ID --lang uk
```

Бутстрапер сам: стягне всі файли в /tmp, перевірить синтаксис, запустить `install.sh` (той поставить залежності, розкладе файли, створить конфіг, підключить cron-аналізатор і запустить обидва сервіси — бота й вотчер подій).

<details>
<summary>Ручна установка (без wget)</summary>

```sh
scp -r tg-router-bot root@192.168.1.2:/tmp/
ssh root@192.168.1.2 "sh /tmp/tg-router-bot/install.sh \
  --token '123456:ABC' --chatid ВАШ_ID --lang ru"
```
</details>

### Налаштування AI (рекомендовано Groq)

```sh
uci set tgbot.config.ai_url='https://api.groq.com/openai/v1/chat/completions'
uci set tgbot.config.ai_model='qwen/qwen3.6-27b'
uci set tgbot.config.ai_key='gsk_...'      # console.groq.com/keys — безкоштовно
uci commit tgbot                            # рестарт не потрібен
```

Альтернативи: Gemini (`aistudio.google.com/apikey`), OpenRouter (50 free/день). Фолбек-ланцюг моделей налаштовується `tgbot.config.ai_groq_chain`.

### Скіли та навчання

```sh
vi /etc/tg-bot/ai/skills/wifi.md        # редагування застосовується одразу
echo '192.168.1.50 = NAS батьків' >> /etc/tg-bot/ai/topology.md
```

---

## Українська

Легкий shell-бот для керування OpenWrt через Telegram: AI-агент (Groq/Gemini), rich-таблиці, гостьовий wifi, проброси, WireGuard, DNS/adblock/SQM — усе голосом, без LuCI.

Встановлення та всі команди — у російському розділі вище; для української: `--lang uk`.

---

## English

A lightweight shell Telegram bot that turns OpenWrt into an AI-managed router: a ReAct-style agent executes `uci/ubus/iwinfo/apk` with confirm-gates, rollback safety-net and per-domain skill files. Multi-provider LLM chain (Groq → fallbacks → OpenRouter), token-economy intent classifier, hourly health analyzer.

Install steps are in the Russian section above; use `--lang en`.

---

## Similar projects

Projects we studied for ideas and inspiration:

| Project | What it is | What we borrowed |
|---------|-----------|------------------|
| [utakamo/oasis](https://github.com/utakamo/oasis) | LuCI AI assistant for OpenWrt (6 providers, tools, sysmsg presets) | Command-string hardening: reject shell metacharacters, control bytes and invisible-unicode spoofing before execution |
| [alexwbaule/telegramopenwrt](https://github.com/alexwbaule/telegramopenwrt) | Bash bot with rich plugin set | Live event pusher idea (`logread -f` → instant DHCP/port alerts), time-based firewall block recipe |
| [Lifailon/openrouter-bot](https://github.com/Lifailon/openrouter-bot) | Go chat client for OpenRouter | On-the-fly model switching (`/model`) |
| [ROUTER-MCP](https://www.glama.ai/mcp/servers/router-mcp-npm-package) | MCP server for router control over SSH | Read-only by default; charset validation of uci arguments against shell injection |
| [mmeisner/telegram-bot](https://github.com/mmeisner/telegram-bot) | Plugin-per-script OpenWrt bot | Modular philosophy |
| [varakh/tlgbot](https://github.com/varakh/tlgbot) | Monitoring-only bash bot | — (covered by our /status /devices) |
| [ixiumu/openwrt-telegram-bot](https://github.com/ixiumu/openwrt-telegram-bot) | Minimal bash bot | — |
| [Habr: DIY Telegram bot](https://habr.com/ru/articles/952868/) | ESP32 + OpenRouter DIY | Message chunking at 3800 chars |

Our thanks to all authors. tg-router-bot differs by being an autonomous ReAct-style **agent** (not a command menu), with confirm-gates, DMS rollback insurance, self-learning corrections and token-economy intent routing.
