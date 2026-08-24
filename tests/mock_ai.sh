#!/bin/sh
# tests/mock_ai.sh — детермінована заглушка OpenAI-сумісного AI endpoint.
#
# Локальна перевірка логіки (без мережі):
#   printf '<HTTP-запит>' | sh tests/mock_ai.sh respond
# Режим сервера (на роутері, TOMORROW):
#   MOCK_PORT=9999 nohup sh tests/mock_ai.sh serve >/tmp/mock.log 2>&1 &
#   uci set tgbot.config.ai_url='http://127.0.0.1:9999/v1/chat/completions'
#   ... прогін сценаріїв ...
#   uci set tgbot.config.ai_url='<старе значення>'; /etc/init.d/tg-bot restart
#
# Маркери в тексті питання -> поведінка:
#   MOCK_S1    SAY-only (без CMD)
#   MOCK_S2    один mutating-CMD (echo mock-ok)
#   MOCK_S3    дворазовий ланцюг: cat → РЕЗУЛЬТАТ КОМАНДЫ → фінал
#   MOCK_JSON  відповідь JSON-обʼєктом замість протоколу (шлях конвертера)
#   MOCK_HTML  CMD загорнутий у <b></b> теги (шлях зачистки)
#   MOCK_EMPTY валідний JSON з порожнім content (шлях ERR/chainfail)

PORT="${MOCK_PORT:-9999}"

esc_json() {
  printf '%s' "$1" \
    | sed 's/\\/\\\\/g; s/"/\\"/g' \
    | tr -d '\000-\010\013\014\016-\037\177' \
    | tr '\n' '\001' | sed 's/\x01/\\n/g'
}

respond() {
  # Сирий HTTP-запит на stdin -> OpenAI-style JSON у stdout
  BODY=$(cat)
  case "$BODY" in
    # Крок 2+ будь-якого ланцюга: прийшов результат команди -> фіналізуємо
    *"РЕЗУЛЬТАТ"*"КОМАНДЫ"*)
      R='CMD: -
SAY: Двокроковий ланцюг відпрацював ✅'
      ;;
    *MOCK_EMPTY*)
      R=""
      ;;
    *MOCK_JSON*)
      R='{"CMD":"echo json-ok","SAY":"JSON перетворено в протокол"}'
      ;;
    *MOCK_HTML*)
      R='CMD: <b>echo html-ok</b>
SAY: Теги <i>зрізано</i> з команди'
      ;;
    *MOCK_S3*)
      R='CMD: head -1 /etc/banner
SAY: Читаю банер...'
      ;;
    *MOCK_S2*)
      R='CMD: echo mock-ok
SAY: Виконую тестову команду...'
      ;;
    *MOCK_S1*|*)
      R='SAY: Mock готово ✅'
      ;;
  esac
  C=$(esc_json "$R")
  printf 'HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nConnection: close\r\n\r\n{"id":"mock","object":"chat.completion","created":0,"model":"mock","choices":[{"index":0,"message":{"role":"assistant","content":"%s"},"finish_reason":"stop"}],"usage":{"prompt_tokens":10,"completion_tokens":10,"total_tokens":20}}\n' "$C"
}

serve() {
  SELF=$(readlink -f "$0" 2>/dev/null || echo "$0")
  case "${MOCK_MODE:-auto}" in
    e|auto)
      if nc 2>&1 | grep -q -- '-e'; then
        echo "mock_ai: nc -e mode on 127.0.0.1:$PORT"
        while :; do
          nc -l -p "$PORT" -e /bin/sh "$SELF" respond
        done
        return
      fi
      [ "${MOCK_MODE:-auto}" = auto ] || return 2
      ;;
  esac
  # FIFO-режим для nc без -e
  D=${MOCK_DIR:-/tmp}
  RF="$D/.mock_req"; WF="$D/.mock_resp"
  rm -f "$RF" "$WF"
  mkfifo "$RF" "$WF" || { echo "mkfifo fail" >&2; exit 3; }
  echo "mock_ai: fifo mode on 127.0.0.1:$PORT"
  while :; do
    ( cat "$WF" | nc -l -p "$PORT" > "$RF"; printf '' > "$WF" ) &
    respond < "$RF" > "$WF"
    sleep 1
  done
}

case "${1:-}" in
  respond) respond ;;
  serve)
    DIR=${MOCK_DIR:-/tmp}
    export DIR
    serve
    ;;
  *) echo "usage: mock_ai.sh respond|serve" >&2; exit 2 ;;
esac
