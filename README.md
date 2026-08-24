# 🤖 tg-router-bot — AI-адміністратор роутера OpenWrt у Telegram

[Русский](#русский) · [Українська](#українська) · [English](#english)

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
- **🔒 Страхівка (DMS)**: мережеві зміни можна виконати «зі страховкою» — 90 с на сигнал життя, інакше авто-відкат конфігів; або `/rollback` вручну
- **Пульс щогодини**, 👀 слежка за людьми по MAC, 👁 моніторинг хостів
- **Самонавчання**: ваші виправлення потрапляють у `corrections.md` і завжди враховуються; факти про роутер — у `facts.md`; топологія — `/topo`
- 🧾 `/ailog` — повний журнал діалогів файлом

### Установка (автоматично)

```sh
# 0) @BotFather → /newbot → токен; свій ID:
curl -s "https://api.telegram.org/bot<TOKEN>/getUpdates" | grep -o '"id":[0-9]*' | head -1

# 1) Скопіюйте файли проєкту на роутер і запустіть інсталятор:
scp -r tg-router-bot root@192.168.1.2:/tmp/
ssh root@192.168.1.2 "sh /tmp/tg-router-bot/install.sh \
  --token '123456:ABC' --chatid 5651093353 --lang ru"
```

Інсталятор сам: поставить залежності, розкладе файли, створить конфіг, підключить cron-аналізатор здоровʼя, запустить сервіс і покаже статус.

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
