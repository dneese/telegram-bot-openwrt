# AGENTS.md — tg-router-bot

Shell-бот Telegram для OpenWrt/ImmortalWrt (busybox ash, ~207 КБ, без Python/Node). Агент ReAct + confirm-gates/DMS-rollback, 13 AI-скилов, меню-кнопки вместо LuCI, WARP/PBR, watchdog.

## Где что

- `tg-bot.sh:1` — ядро (~3389 строк): longpoll Telegram, локализация `T_*_ru/en/uk`, меню `mk_markups`, AI-агент (`ai_run`, `sanitize_cmd`, `cmd_banned`, `is_mut`), быстрые ответы `fast_intent`/`qmatch`.
- `tg-watch.sh:1` / `tg-watch.init` / `tg-doctor.sh` / `tg-doctor.hotplug` — live-push DHCP/link events (`watch_match`), hotplug.
- `tg-bot.init` / `tg-analyze.sh` — procd-демон + ежечасный анализатор (cron `0 * * * *` в `install.sh:131`).
- `tgbot.settings.js:1` / `tgbot.menu.json` / `tgbot.acl.json` — LuCI-страница `Services → Telegram Bot`.
- `prompts/core.txt:1` — системный промпт агента (формат `CMD:`/`SAY:`/`PLAN:`, батч `CMD`/`CMD2`/`CMD3`).
- `prompts/skills/*.md` (7) — скилы агента; `prompts/kb/*.md` (13) — база знаний GitHub (`BASE` в `core.txt:15`); `prompts/learned/lessons.md` — самонавчання.
- `firmware/files/` — overlay для ImageBuilder (uci-defaults `99-tgbot-setup`, `etc/config/tgbot`).
- `tests/run_tests.sh:1` + `tests/mock_ai.sh` — оффлайн-тесты; `.github/workflows/` — CI.

## Команды

```sh
# Синтаксис (CI делает это первым)
sh -n tg-bot.sh && sh -n tg-watch.sh && sh -n install.sh && sh -n tg-installer.sh

# Тесты — 147 оффлайн-проверок, без API и мутаций, моки через awk-извлечение функций
sh tests/run_tests.sh tg-bot.sh                          # только бот
sh tests/run_tests.sh /storage/emulated/0/Documents/tg-router-bot/tg-bot.sh /storage/emulated/0/Documents/tg-router-bot/tg-watch.sh  # + watch_match
sh tests/run_tests.sh tg-bot.sh 2>&1 | tail -20          # PASS/FAIL сводка

# Установка на роутере (apk-based OpenWrt 17.x+/ImmortalWrt)
sh install.sh --token '123:ABC' --chatid 12345 --lang uk --key 'gsk_...' --model 'qwen/qwen3.6-27b'
sh install.sh --uninstall
# Бутстрап с GitHub (тянет файлы в /tmp/tgrb.$$ через uclient-fetch/curl/wget)
sh tg-installer.sh --token '123:ABC' --chatid 12345 --lang ru
```

CI: `tests.yml` — `sh -n` + `run_tests.sh`; `firmware.yml` / `firmware-xiaomi.yml` — сборка ImageBuilder (LEDE 17.01.7 `tl-wr741nd-v4`, OpenWrt 25.12.5 `xiaomi_mi-router-4a-gigabit`).

## Архитектура и инварианты

- **busybox-only**: `ash`, `uci`, `ubus`, `iwinfo`, `apk`/`opkg`, `jsonfilter`, `curl`/`uclient-fetch`. Нет bash-измов, нет внешних рантаймов.
- **Мутации только по одной с подтверждением**: `is_mut()` + `sanitize_cmd()` (отклоняет `$()`/`` ` ``/`${}`/`;`-цепочки/одиночный `&`/control-bytes/zero-width) + `cmd_banned()` (блокирует `rm -rf`/`nft flush`/`iptables -F` а-ля `sanitize_cmd()` + `cmd_banned()` в `tests/run_tests.sh:128`). Чтение можно батчить `CMD`/`CMD2`/`CMD3` (см. `core.txt:3`), `;` внутри одной строки запрещён.
- **Извлечение функций для тестов**: `tests/run_tests.sh:15` `xf()` — `awk` ищет `fn"("` в начале строки + ` {`; `}` закрывает. Добавляя функцию — соблюдай этот стиль, иначе `EXTRACT FAIL`.
- **UCI**: изменения требуют `uci commit <section>` (авто-дописывает `uci_autocommit`), проверка обратным чтением; `network restart` только при смене LAN IP/WAN proto.
- **Ключи AI** маршрутизируются по префиксу `key_slot()` в `tests/run_tests.sh:227`: `gsk_→ai_key`, `sk-or-v1→ai_key2`, иное→`ai_key3` (та же логика в `install.sh:106` и `/key` в боте).
- **Язык** `tgbot.config.lang` (`ru`/`uk`/`en`), фолбэк `ru` (`tg-bot.sh:18`).

## Workflow / Gotchas

- **Путь на Termux**: репо лежит в `/storage/emulated/0/Documents/tg-router-bot` (доступно и как `/sdcard/Documents/tg-router-bot`), а не в `$HOME` (`/data/data/com.termux/files/home`). Для `Glob`/`Grep`/`Read` указывай полный путь.
- **Termux-окружение**: `git`/`which`/`file` могут отсутствовать — `apt update && apt install git` если нужен `git status`. `/` нечитаем.
- **Не перезаписывать** `prompts/corrections.md` и `prompts/topology.md` при установке если непустые (`install.sh:83`).
- **Добавление скила/КБ**: положи `.md` в `prompts/skills/` или `prompts/kb/` и пропиши тему в `core.txt:16` + `BASE` логике; для `skill_pick`/`kb_pick` порядок приоритетов важен (`tests/run_tests.sh:164`).
- **WARP/PBR**: `nftables set + fwmark`, список `blocked.list` (112 CIDR), `DMS` 90с авто-отката — не тривиально менять без тестов.
- Перед PR: `sh -n` → `sh tests/run_tests.sh tg-bot.sh` → проверь `*.md` скилы на короткие команды (без `;`).
