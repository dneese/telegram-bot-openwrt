# 🤖 tg-router-bot — Легкий Telegram-бот для OpenWrt (Light, без AI)

[Русский](#русский) · [Українська](#українська) · [English](#english)

> **Light-ветка:** только Telegram-управление роутером, без AI-агента, минимальный размер для 4M flash.

Кишеньковий адміністратор: керуєш роутером кнопками в Telegram — Wi-Fi, файрвол, діагностика, VPN/WARP, бекапи — без LuCI.

**Мови:** ru / uk / en (фільтр `install.sh --lang ru` → ~113K) · **Без AI, без Python/Node** · **WARP збережено**

---

## Русский

Shell-бот (~143 КБ, 113K с `--lang ru`, busybox-only) для ImmortalWrt/OpenWrt 17.x+ (apk/opkg). Без AI, без Python/Node. VPN/WARP, PBR, watchdog, меню 2 в ряд, редактирование одного сообщения.

### Возможности (Light)

- **🗂 Меню 2 в ряд — бот замість LuCI**: все кнопками, **одно сообщение редактируется** (нет спама), `⬅️ Меню` везде
- **📶 Wi-Fi**: список сетей → **канал** кнопками `1|6` / `11|auto` (2G) и `36|40` / `44|48` / `149|auto` (5G, непересекающиеся), **пароль** 8-63, **SSID**, **мощность** 10/20/max, **вкл/выкл** — с подтверждением `✅ Выполнить / 🔒 Со страховкой`
- **🛡 Фаєрвол**: портфорварды `wan` (тап=удалить), мастер добавления
- **🔧 Діагностика**: `ping`/`traceroute`/`nslookup` (в фоне), логи
- **⚙️ Система**: WAN, бекап, ребут, `↩️ Rollback`, пакеты `apk`, SSH-ключи
- **🌐 VPN/WARP**: статус, подключение (авто-регистрация Cloudflare), весь трафик/стоп, PBR (112 CIDR → nftables), MTU-тест, пинг
- **Rich-таблиці**: статус, устройства, скан — таблицы Telegram
- **Страхівка DMS**: 90с авто-відкат, `/rollback`
- **Watchdog/tg-watch/pulse** — как в full

### Установка (одна команда, Light)

```sh
# @BotFather → /newbot → токен; свой ID:
curl -s "https://api.telegram.org/bot<TOKEN>/getUpdates" | grep -o '"id":[0-9]*' | head -1

# На роутері — light, русский, минимальный (wifi+warp, ~113K):
wget -O - https://raw.githubusercontent.com/dneese/telegram-bot-openwrt/light/tg-installer.sh | sh -s -- --token '123456:ABC' --chatid ВАШ_ID --lang ru --minimal

# light, все модули, русский (~143K):
wget -O - https://raw.githubusercontent.com/dneese/telegram-bot-openwrt/light/tg-installer.sh | sh -s -- --token '123:ABC' --chatid ВАШ_ID --lang ru

# все языки (~144K):
wget -O - https://raw.githubusercontent.com/dneese/telegram-bot-openwrt/light/tg-installer.sh | sh -s -- --token '123:ABC' --chatid ВАШ_ID --lang all
# выборочно:
wget -O - https://raw.githubusercontent.com/dneese/telegram-bot-openwrt/light/tg-installer.sh | sh -s -- --token '...' --chatid ... --lang ru --modules wifi,warp,firewall
```

**Размер на роутере (light):** `tg-bot.sh 141K` (113K с `--lang ru`), `/etc/tg-bot ~22K`, overlay `1.1M/4.7M (24%)` vs full `1.4M (29%)`, экономия ~140K.

### Тести

```sh
sh tests/run_tests.sh tg-bot.sh tg-watch.sh  # light: 71 проверка, без AI
sh -n tg-bot.sh && sh -n install.sh
```

---

## Українська

Легкий shell-бот (~143 КБ, 113K з `--lang uk`) для OpenWrt: меню 2 в ряд, Wi-Fi канал кнопками, WARP/PBR, бекапи, watchdog — без AI, без LuCI, procd-демон.

---

## English

Light shell bot (~143KB, 113KB with `--lang en`, busybox-only) for OpenWrt: 2-col menu, Wi-Fi channel buttons (1,6,11/auto), WARP/PBR, rich tables, single-message edit, no AI, no Python/Node.

---

## Full vs Light

| Ветка | Размер | AI | Языки | Тесты | Фичи |
|-------|--------|----|-------|-------|------|
| `master` (full) | 207K (144K + prompts) | ✅ Groq/Gemini/OpenRouter, 13 скилов | 3 | 147 | AI-агент, самонавчання, `/ai` |
| `light` | **141K (113K ru)** | ❌ | 1-3 (фильтр) | **71** | Только Telegram-кнопки, WARP сохранён |

Light — для 4M flash и тех, кому не нужен AI.

---

## Similar projects

| Project | What we borrowed |
|---------|------------------|
| [utakamo/oasis](https://github.com/utakamo/oasis) | hardening |
| [alexwbaule/telegramopenwrt](https://github.com/alexwbaule/telegramopenwrt) | live-push |

