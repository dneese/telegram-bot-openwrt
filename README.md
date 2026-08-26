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

Shell-бот (~207 КБ, busybox-only) для ImmortalWrt/OpenWrt 17.x+ (apk/opkg). Без Python/Node. Вбудований VPN/WARP, PBR, watchdog та web-майстер першого налаштування.

### Возможности

- **🗂 Розширене меню — бот замість LuCI**: усі налаштування роутера кнопками прямо в Telegram (див. нижче)
- **🤖 AI-агент**: «зроби гостьовий wifi», «хто найбільше качає», «встанови DNS Google» — агент сам виконує команди і звітує. Знання розкладено по **скілах** (13 файлів: `wireless.md`, `dns.md`, `firewall.md`, `warp.md`, `wireguard.md`, …)
- **Швидкі дії без токенів**: типові питання (пристрої/скан/стан) йдуть через intent-класифікатор (~250 токенів замість ~3000)
- **Rich-таблиці** (Bot API 10.x): пристрої, скан ефіру, статус — справжні таблиці Telegram
- **🌐 VPN/WARP**: реєстрація Cloudflare WARP-тунелю кнопкою, підключення/відключення, весь трафік через WARP, MTU-тестер, endpoint-пінг. PBR: ручний список заблокованих IP (112 CIDR) → nftables set + fwmark → лише ці IP через WARP
- **🔒 Страхівка (DMS)**: мережеві зміни можна виконати «зі страховкою» — 90 с на сигнал життя, інакше авто-відкат конфігів; або `/rollback` вручну
- **⚙️ /model**: зміна основної AI-моделі прямо з чату кнопкою — застосовується одразу, без рестарту і SSH
- **🌐 tg-watch** (live-push): нова DHCP-аренда чи падіння порту — миттєве повідомлення в чат (`logread -f`, дедуп 10 хв + rate-limit; тихий режим: `uci set tgbot.config.watch_quiet=1`)
- **🛡 Watchdog**: автоматичне відновлення WARP, PBR-правил та бота після падінь/ребутів (cron */2)
- **Пульс щогодини**, 👀 слежка за людьми по MAC, 👁 моніторинг хостів
- **Безпека**: підтвердження кнопкою на зміни, diff preview (`uci changes`), авто-дописування `commit`, маскування паролів у відповідях, блок rm -rf/mkfs/dd/sysupgrade
- **Захист у глибину**: `sanitize_cmd()` відхиляє підстановки `$()`/`` ` ``/`${}`, `;`-ланцюжки, одиночний `&`, керуючі байти та zero-width/RTL-спуф у командах від моделі (ідея: [oasis security_guard](https://github.com/utakamo/oasis))
- **Самонавчання**: ваші виправлення потрапляють у `corrections.md` і завжди враховуються; факти про роутер — у `facts.md`; топологія — `/topo`
- 🧾 `/ailog` — повний журнал діалогів файлом
- **🏭 Прошивка**: готовий образ для TP-Link TL-WR741ND v4 (4 МБ flash, LEDE 17.01.7) та Xiaomi Mi Router 4A Gigabit (16 МБ flash, OpenWrt 25.12.5) з вбудованим ботом та web-майстром першого налаштування

### 🗂 Розширене меню (заміна LuCI)

`/start` → головне меню з розділами; навігація кнопкою «⬅️ Меню»:

| Розділ | Що вміє |
|--------|---------|
| **📶 Wi-Fi** | список усіх мереж зі статусом/каналом → змінити **пароль** (валідація 8–63), **SSID**, **канал**, **потужність** (10/20/max dBm), **увімк/вимк** радіо. Швидкі дії: QR Wi-Fi, скан ефіру |
| **🛡 Фаєрвол** | список портфорвордів WAN (**тап по правилу = видалити**), ➕ майстер додавання: протокол → зовнішній порт → внутрішня IP → внутрішній порт |
| **🔧 Діагностика** | `ping` / `traceroute` / `nslookup` з роутера (важкі — у фоні, результат окремим повідомленням); системний лог і лог ядра файлом (останні 150 рядків) |
| **⚙️ Система** | перепідключення WAN · бекап конфігів · перезавантаження · **↩️ Rollback** до знімка · 📦 пакети (пошук + `apk add/del`) · 🔑 SSH-ключі dropbear (список / додати / видалити) |
| **🌐 VPN** | 📊 Статус WARP · ⚡️ Підключити (авто-реєстрація через Cloudflare API) · 🟢 Весь трафік / ⏸ Припинити · 🗑 Видалити WARP · 📋 PBR (список заблокованих IP, ➕/🗑/🔄) · 📏 MTU-тест · 📡 Пінг endpoint |
| **👀 Моніторинг** | live-push подій (нова DHCP-аренда, падіння порту) |
| **🏷 Імена** | aliases для MAC-адрес пристроїв |

Кожна зміна проходить через підтвердження: **✅ Виконати · 🔒 Зі страховкою (DMS-автовідкат 90 с) · ❌**. Ввід текстом валідується (порти, IPv4, SSID без апострофів і керуючих байтів, формат SSH-ключа). Додаткові команди: `/wifi`, `/topo`, `/rollback`.

### 🧠 AI-скіли (13 файлів)

| Скіл | Опис |
|------|------|
| `wireless.md` | Wi-Fi мережі, паролі, канали, TX power |
| `dns.md` | DNS-сервери, /etc/resolv.conf |
| `firewall.md` | Портфорворди, правила файрвола |
| `network.md` | Мережа, інтерфейси, маршрути |
| `services.md` | Сервіси, init.d, procd |
| `packages.md` | apk/opkg пакети |
| `diagnostics.md` | ping, traceroute, nslookup, логи |
| `security.md` | SSH-ключі, обмеження доступу |
| `performance.md` | SQM, QoS, оптимізація |
| `vpnother.md` | WireGuard, OpenVPN, інші VPN |
| `warp.md` | Cloudflare WARP — реєстрація, тунель, режими |
| `wireguard.md` | WireGuard — конфігурація, піри |
| `zaborona.md` | Блокування/обхід обмежень |

### ✅ Тести

```sh
sh tests/run_tests.sh tg-bot.sh        # локально або на роутері: 147 офлайн-перевірок
```

Без API-запитів і мутацій: чисті функції витягуються awk'ом і гоняються з моками. CI запускає їх автоматично на кожен push (GitHub Actions).

### Установка (одна команда)

```sh
# 0) @BotFather → /newbot → токен; свій ID:
curl -s "https://api.telegram.org/bot<TOKEN>/getUpdates" | grep -o '"id":[0-9]*' | head -1

# 1) На роутері (завантажить усі файли з GitHub і запустить інсталятор):
wget -O - https://raw.githubusercontent.com/dneese/telegram-bot-openwrt/master/tg-installer.sh | sh \
  -s -- --token '123456:ABC' --chatid ВАШ_ID --lang uk
```

<details>
<summary>📱 Вузький термінал ламає довгі рядки? 4 крихітні команди</summary>

```sh
cd /tmp
```
```sh
U=ulvis.net/69K4
```
```sh
uclient-fetch -O i https://$U
```
```sh
sh i
```
Інсталятор сам поставить питання про токен/chatid/мову.
</details>

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

Легкий shell-бот (~207 КБ, busybox-only) для керування OpenWrt через Telegram: AI-агент (Groq/Gemini), rich-таблиці, Wi-Fi, файрвол, діагностика, VPN/WARP з PBR, watchdog, web-майстер першого налаштування — усе кнопками, без LuCI.

13 AI-скілів, 147 тестів, procd-демон з автозапуском. Вбудована прошивка для TP-Link TL-WR741ND v4 (4 МБ) та Xiaomi Mi Router 4A Gigabit (16 МБ).

Встановлення та всі команди — у російському розділі вище; для української: `--lang uk`.

---

## English

A shell Telegram bot (~207 KB, busybox-only) that turns OpenWrt/ImmortalWrt into an AI-managed router. A ReAct-style agent executes `uci/ubus/iwinfo/apk` with confirm-gates, rollback safety-net and per-domain skill files.

**Features:** Full menu system (Wi-Fi, firewall, diagnostics, system, VPN/WARP with PBR, monitoring), multi-provider LLM chain (Groq → fallbacks → OpenRouter), token-economy intent classifier, Cloudflare WARP auto-registration, policy-based routing (nftables + fwmark), watchdog with auto-recovery, hourly health analyzer, self-learning corrections.

**Tech:** 107 shell functions, 147 tests, 13 AI skills, 3 languages (ru/uk/en), procd daemon, CI on GitHub Actions. Firmware builds for TP-Link TL-WR741ND v4 (4 MB flash, LEDE 17.01.7) and Xiaomi Mi Router 4A Gigabit (16 MB flash, OpenWrt 25.12.5) with web setup wizard.

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
