#!/bin/sh
# tg-bot.sh — Telegram-бот управления OpenWrt
# Пульс + команды + inline-кнопки + backup + алиасы + присутствие
# + QR Wi-Fi + скан сетей + мониторинг хостов
# Запускается как демон через procd (/etc/init.d/tg-bot)

TOKEN="$(uci -q get tgbot.config.token)"
CHAT="$(uci -q get tgbot.config.chatid)"
[ -z "$TOKEN" ] && exit 0
[ -z "$CHAT" ] && exit 0
API="https://api.telegram.org/bot$TOKEN"
DIR="/etc/tg-bot"
export PATH="/usr/sbin:/usr/bin:/sbin:/bin"
PULSE_INTERVAL=3600
LONGPOLL=25
BOT_LANG="$(uci -q get tgbot.config.lang 2>/dev/null)"
[ -z "$BOT_LANG" ] && BOT_LANG="${TGBOT_LANG:-ru}"
case "$BOT_LANG" in en|uk|ru) ;; *) BOT_LANG=ru ;; esac

# --- локализация: ключ -> строка по языкам (ru/en/uk); t <key> ---
t() { eval "printf '%b' \"\$T_${1}_$BOT_LANG\""; }

T_btn_status_ru='📊 Статус'; T_btn_status_en='📊 Status'; T_btn_status_uk='📊 Статус'
T_btn_dev_ru='📱 Устройства'; T_btn_dev_en='📱 Devices'; T_btn_dev_uk='📱 Пристрої'
T_btn_scan_ru='📡 Wi-Fi скан'; T_btn_scan_en='📡 Wi-Fi scan'; T_btn_scan_uk='📡 Wi-Fi скан'
T_btn_qr_ru='🔑 QR Wi-Fi'; T_btn_qr_en='🔑 QR Wi-Fi'; T_btn_qr_uk='🔑 QR Wi-Fi'
T_btn_bk_ru='💾 Бэкап'; T_btn_bk_en='💾 Backup'; T_btn_bk_uk='💾 Бекап'
T_btn_ai_ru='🤖 AI-чат'; T_btn_ai_en='🤖 AI chat'; T_btn_ai_uk='🤖 AI-чат'
T_btn_watch_ru='👀 Слежка'; T_btn_watch_en='👀 Watch'; T_btn_watch_uk='👀 Слідкування'
T_btn_alias_ru='🏷 Имена'; T_btn_alias_en='🏷 Names'; T_btn_alias_uk='🏷 Імена'
T_btn_wan_ru='🌐 Интернет'; T_btn_wan_en='🌐 Internet'; T_btn_wan_uk='🌐 Інтернет'
T_btn_rb_ru='⚡️ Перезагрузка'; T_btn_rb_en='⚡️ Reboot'; T_btn_rb_uk='⚡️ Перезавантаження'
T_btn_help_ru='❓ Помощь'; T_btn_help_en='❓ Help'; T_btn_help_uk='❓ Довідка'
T_rbyes_ru='✅ Да, перезагрузить!'; T_rbyes_en='✅ Yes, reboot!'; T_rbyes_uk='✅ Так, перезавантажити!'
T_rbno_ru='❌ Отмена'; T_rbno_en='❌ Cancel'; T_rbno_uk='❌ Скасувати'
T_aic1_ru='✅ Выполнить'; T_aic1_en='✅ Execute'; T_aic1_uk='✅ Виконати'
T_aic2_ru='🔒 Со страховкой'; T_aic2_en='🔒 Safety-net run'; T_aic2_uk='🔒 Зі страховкою'
T_aic0_ru='❌ Отмена'; T_aic0_en='❌ Cancel'; T_aic0_uk='❌ Скасувати'
T_aioff_ru='⛔️ Выйти из AI'; T_aioff_en='⛔️ Exit AI'; T_aioff_uk='⛔️ Вийти з AI'
T_mnback_ru='⬅️ Меню'; T_mnback_en='⬅️ Menu'; T_mnback_uk='⬅️ Меню'

T_net_yes_ru='✅ есть'; T_net_yes_en='✅ up'; T_net_yes_uk='✅ є'
T_net_no_ru='❌ нет'; T_net_no_en='❌ down'; T_net_no_uk='❌ немає'
T_u_min_ru='%s мин'; T_u_min_en='%s min'; T_u_min_uk='%s хв'
T_u_day_ru='%s дн %s ч %s мин'; T_u_day_en='%sd %sh %sm'; T_u_day_uk='%s дн %s год %s хв'
T_u_hm_ru='%s ч %s мин'; T_u_hm_en='%sh %sm'; T_u_hm_uk='%s год %s хв'
T_s_up_ru='⏱ Аптайм'; T_s_up_en='⏱ Uptime'; T_s_up_uk='⏱ Аптайм'
T_s_load_ru='📈 Load'; T_s_load_en='📈 Load'; T_s_load_uk='📈 Load'
T_s_ram_ru='🧠 RAM'; T_s_ram_en='🧠 RAM'; T_s_ram_uk='🧠 RAM'
T_s_wan_ru='🌐 WAN'; T_s_wan_en='🌐 WAN'; T_s_wan_uk='🌐 WAN'
T_s_pub_ru='🌍 Публичный IP'; T_s_pub_en='🌍 Public IP'; T_s_pub_uk='🌍 Публічний IP'
T_s_net_ru='🔗 Интернет'; T_s_net_en='🔗 Internet'; T_s_net_uk='🔗 Інтернет'
T_s_hdr_ru='<b>📊 Статус роутера</b>'; T_s_hdr_en='<b>📊 Router status</b>'; T_s_hdr_uk='<b>📊 Статус роутера</b>'
T_m_title_ru='🤖 <b>Роутер</b> · ⏱ %s · 🔗 %s\nВыбирайте кнопки 👇'; T_m_title_en='🤖 <b>Router</b> · ⏱ %s · 🔗 %s\nPick a button 👇'; T_m_title_uk='🤖 <b>Роутер</b> · ⏱ %s · 🔗 %s\nОбирайте кнопки 👇'
T_d_none_ru='📭 DHCP-аренды не найдены'; T_d_none_en='📭 No DHCP leases found'; T_d_none_uk='📭 DHCP-аренд не знайдено'
T_d_hdr_ru='<b>📶 Устройства</b> · 🟢 онлайн: %s из %s'; T_d_hdr_en='<b>📶 Devices</b> · 🟢 online: %s of %s'; T_d_hdr_uk='<b>📶 Пристрої</b> · 🟢 онлайн: %s із %s'
T_d_on_ru='\n<b>📍 В сети</b>\n%s'; T_d_on_en='\n<b>📍 Online</b>\n%s'; T_d_on_uk='\n<b>📍 В мережі</b>\n%s'
T_d_off_ru='\n\n<b>📍 Не в сети</b>\n%s'; T_d_off_en='\n\n<b>📍 Offline</b>\n%s'; T_d_off_uk='\n\n<b>📍 Не в мережі</b>\n%s'
T_d_name_ru='устройство'; T_d_name_en='device'; T_d_name_uk='пристрій'
T_help_ru='<b>🤖 Управление роутером</b>\n\n<b>📍 Основное</b>\n<code>/status</code> · статус системы\n<code>/devices</code> · устройства в сети\n<code>/wan</code> · переподключить интернет\n<code>/reboot yes</code> · перезагрузка\n\n<b>📍 Инструменты</b>\n<code>/wifi</code> · меню Wi-Fi (пароль/SSID/канал/мощность)\n<code>/backup</code> · бэкап конфигов файлом сюда\n<code>/qr</code> · QR для подключения к Wi-Fi\n<code>/scan</code> · скан соседних сетей\n<code>/rollback</code> · откат конфигов к снимку\n<code>/topo IP опис</code> · запомнить устройство\n<code>/ai вопрос</code> · AI-агент (знает состояние, делает изменения)\n<code>/model</code> · сменить AI-модель · <code>/key КЛЮЧ</code>\n<code>/usage</code> · расход токенов · <code>/cancel</code> · отмена\n\n<b>📍 Алиасы и слежка</b>\n<code>/alias IP Имя</code> · своё имя устройству\n<code>/watch add MAC Имя</code> · следить за человеком\n<code>/mon add host Метка</code> · мониторинг хоста\n\n✅ <i>Меню /start: Wi-Fi · Файрвол · Диагностика · Система. Пульс ежечасный.</i>'
T_help_en='<b>🤖 Router control</b>\n\n<b>📍 Basics</b>\n<code>/status</code> · system status\n<code>/devices</code> · network devices\n<code>/wan</code> · reconnect internet\n<code>/reboot yes</code> · reboot\n\n<b>📍 Tools</b>\n<code>/wifi</code> · Wi-Fi menu (password/SSID/channel/power)\n<code>/backup</code> · config backup as a file here\n<code>/qr</code> · Wi-Fi connect QR code\n<code>/scan</code> · scan nearby networks\n<code>/rollback</code> · restore config snapshot\n<code>/topo IP desc</code> · remember a device\n<code>/ai question</code> · AI agent (knows the state, makes changes)\n<code>/model</code> · switch AI model · <code>/key KEY</code>\n<code>/usage</code> · token usage · <code>/cancel</code> · cancel\n\n<b>📍 Aliases and watching</b>\n<code>/alias IP Name</code> · custom device name\n<code>/watch add MAC Name</code> · watch a person\n<code>/mon add host Label</code> · host monitoring\n\n✅ <i>/start menu: Wi-Fi · Firewall · Diagnostics · System. Hourly heartbeat.</i>'
T_help_uk='<b>🤖 Керування роутером</b>\n\n<b>📍 Основне</b>\n<code>/status</code> · статус системи\n<code>/devices</code> · пристрої в мережі\n<code>/wan</code> · перепідключити інтернет\n<code>/reboot yes</code> · перезавантаження\n\n<b>📍 Інструменти</b>\n<code>/wifi</code> · меню Wi-Fi (пароль/SSID/канал/потужність)\n<code>/backup</code> · бекап конфігів файлом сюди\n<code>/qr</code> · QR для підключення до Wi-Fi\n<code>/scan</code> · скан сусідніх мереж\n<code>/rollback</code> · відкат конфігів до знімка\n<code>/topo IP опис</code> · запамʼятати пристрій\n<code>/ai питання</code> · AI-агент (знає стан, робить зміни)\n<code>/model</code> · змінити AI-модель · <code>/key КЛЮЧ</code>\n<code>/usage</code> · витрати токенів · <code>/cancel</code> · скасувати\n\n<b>📍 Аліаси та слідкування</b>\n<code>/alias IP Назва</code> · свою назву пристрою\n<code>/watch add MAC Назва</code> · слідкувати за людиною\n<code>/mon add host Мітка</code> · моніторинг хоста\n\n✅ <i>Меню /start: Wi-Fi · Фаєрвол · Діагностика · Система. Пульс щогодинний.</i>'
T_al_help_ru='🏷 <b>Свои имена устройств</b>\n\nЗадать имя:\n<code>/alias 192.168.1.105 Ноутбук</code>\n\nУбрать имя:\n<code>/alias del 192.168.1.105</code>\n\nИмена видны в 📱 Устройствах и в 👀 Слежке.'
T_al_help_en='🏷 <b>Custom device names</b>\n\nSet a name:\n<code>/alias 192.168.1.105 Laptop</code>\n\nRemove a name:\n<code>/alias del 192.168.1.105</code>\n\nNames appear in 📱 Devices and 👀 Watch.'
T_al_help_uk='🏷 <b>Свої назви пристроїв</b>\n\nЗадати назву:\n<code>/alias 192.168.1.105 Ноутбук</code>\n\nПрибрати назву:\n<code>/alias del 192.168.1.105</code>\n\nНазви видно в 📱 Пристроях та 👀 Слідкуванні.'
T_b_gather_ru='📦 Собираю бэкап...'; T_b_gather_en='📦 Building backup...'; T_b_gather_uk='📦 Збираю бекап...'
T_b_ok_ru='💾 Бэкап конфигов готов.\nАрхив приложен к сообщению.'; T_b_ok_en='💾 Config backup ready.\nArchive attached.'; T_b_ok_uk='💾 Бекап конфігів готовий.\nАрхів прикріплений до повідомлення.'
T_b_fail_ru='❌ Не удалось создать архив'; T_b_fail_en='❌ Failed to create archive'; T_b_fail_uk='❌ Не вдалося створити архів'
T_q_notfound_ru='❌ Не нашёл настройки Wi-Fi'; T_q_notfound_en='❌ Wi-Fi settings not found'; T_q_notfound_uk='❌ Не знайшов налаштувань Wi-Fi'
T_q_cap_ru='📶 Сеть: <b>%s</b>\nНаведите камеру для подключения'; T_q_cap_en='📶 Network: <b>%s</b>\nPoint your camera to connect'; T_q_cap_uk='📶 Мережа: <b>%s</b>\nНаведіть камеру для підключення'
T_q_note_ru='\n<i>QR создан через внешний сервис api.qrserver.com</i>'; T_q_note_en='\n<i>QR generated via external service api.qrserver.com</i>'; T_q_note_uk='\n<i>QR створено через зовнішній сервіс api.qrserver.com</i>'
T_sc_doing_ru='📡 Сканирую (%s)...'; T_sc_doing_en='📡 Scanning (%s)...'; T_sc_doing_uk='📡 Сканую (%s)...'
T_sc_nosup_ru='❌ Сканирование не поддерживается'; T_sc_nosup_en='❌ Scanning not supported'; T_sc_nosup_uk='❌ Сканування не підтримується'
T_sc_empty_ru='❌ Пустой результат скана'; T_sc_empty_en='❌ Empty scan result'; T_sc_empty_uk='❌ Порожній результат скану'
T_sc_hdr_ru='📡 Сети вокруг'; T_sc_hdr_en='📡 Nearby networks'; T_sc_hdr_uk='📡 Мережі навколо'
T_sc_busy_ru='📻 Занятость каналов:'; T_sc_busy_en='📻 Channel usage:'; T_sc_busy_uk='📻 Зайнятість каналів:'
T_sc_busy5_ru='📻 Занятость каналов:'; T_sc_busy5_en='📻 Channel usage:'; T_sc_busy5_uk='📻 Зайнятість каналів:'
T_sc_b24_ru='📶 Диапазон 2.4 ГГц'; T_sc_b24_en='📶 2.4 GHz band'; T_sc_b24_uk='📶 Діапазон 2.4 ГГц'
T_sc_b5_ru='📶 Диапазон 5 ГГц'; T_sc_b5_en='📶 5 GHz band'; T_sc_b5_uk='📶 Діапазон 5 ГГц'
T_sc_adv_ru='💡 Совет: канал <b>%s</b> свободнее всех (с учётом силы соседей)'; T_sc_adv_en='💡 Tip: channel <b>%s</b> is least busy (neighbor strength counted)'; T_sc_adv_uk='💡 Порада: канал <b>%s</b> найвільніший (з урахуванням сили сусідів)'
T_sc_adv5_ru='💡 Для 5 ГГц свободнее: канал <b>%s</b>'; T_sc_adv5_en='💡 For 5 GHz the freest channel is <b>%s</b>'; T_sc_adv5_uk='💡 Для 5 ГГц найвільніший: канал <b>%s</b>'
T_sc_keep_ru='✅ Ваш канал <b>%s</b> вже найвільніший — переїзд не потрібен'; T_sc_keep_en='✅ Your channel <b>%s</b> is already the freest — no need to move'; T_sc_keep_uk='✅ Ваш канал <b>%s</b> уже найвільніший — переїзд не потрібен'
T_sc_stay_ru='💡 Найчистіший зараз канал <b>%s</b>, але різниця з вашим мала — переїзд не обовʼязковий'; T_sc_stay_en='💡 Channel <b>%s</b> is cleanest now, but the difference is small — moving is optional'; T_sc_stay_uk='💡 Найчистіший зараз канал <b>%s</b>, але різниця з вашим мала — переїзд не обовʼязковий'
T_sc_top_ru='📍 Топ по сигналу:'; T_sc_top_en='📍 Top by signal:'; T_sc_top_uk='📍 Топ за сигналом:'
T_sc_total_ru='Всего сетей: <i>%s</i>'; T_sc_total_en='Total networks: <i>%s</i>'; T_sc_total_uk='Всього мереж: <i>%s</i>'
T_al_fmt_ru='Формат: /alias 192.168.1.105 Ноутбук'; T_al_fmt_en='Format: /alias 192.168.1.105 Laptop'; T_al_fmt_uk='Формат: /alias 192.168.1.105 Ноутбук'
T_al_delfmt_ru='Формат: /alias del IP'; T_al_delfmt_en='Format: /alias del IP'; T_al_delfmt_uk='Формат: /alias del IP'
T_al_badip_ru='❌ IP выглядит странно'; T_al_badip_en='❌ IP looks odd'; T_al_badip_uk='❌ IP виглядає дивно'
T_al_done_ru='🏷 Готово: %s = <b>%s</b>'; T_al_done_en='🏷 Done: %s = <b>%s</b>'; T_al_done_uk='🏷 Готово: %s = <b>%s</b>'
T_al_del_ru='🗑 Алиас %s удалён'; T_al_del_en='🗑 Alias %s removed'; T_al_del_uk='🗑 Аліас %s видалено'
T_wl_empty_ru='👀 Список пуст. Добавить: /watch add AA:BB:CC:DD:EE:FF Жена'; T_wl_empty_en='👀 List empty. Add: /watch add AA:BB:CC:DD:EE:FF Wife'; T_wl_empty_uk='👀 Список порожній. Додати: /watch add AA:BB:CC:DD:EE:FF Дружина'
T_wl_hdr_ru='<b>👀 Наблюдаемые:</b>'; T_wl_hdr_en='<b>👀 Watched:</b>'; T_wl_hdr_uk='<b>👀 Під наглядом:</b>'
T_w_badmac_ru='Формат MAC: AA:BB:CC:DD:EE:FF'; T_w_badmac_en='MAC format: AA:BB:CC:DD:EE:FF'; T_w_badmac_uk='Формат MAC: AA:BB:CC:DD:EE:FF'
T_w_del_ru='🗑 Убрал из наблюдения'; T_w_del_en='🗑 Removed from watch'; T_w_del_uk='🗑 Прибрано з нагляду'
T_w_intro_ru='<b>👀 Слежка за людьми</b>\nТапните по человеку — бот сообщит о\nприходе 🏠 и уходе 👋 (по MAC телефона)\n\n✅ — уже под наблюдением (тап = убрать)'
T_w_intro_en='<b>👀 People watching</b>\nTap a person — the bot reports arrival 🏠\nand departure 👋 (by phone MAC)\n\n✅ — already watched (tap to remove)'
T_w_intro_uk='<b>👀 Слідкування за людьми</b>\nТапніть по людині — бот повідомить про\nприхід 🏠 і відхід 👋 (по MAC телефону)\n\n✅ — вже під наглядом (тап = прибрати)'
T_w_empty_ru='Пока никто не найден в DHCP-арендах.'; T_w_empty_en='No one found in DHCP leases yet.'; T_w_empty_uk='Поки нікого не знайдено в DHCP-ардах.'
T_w_follow_ru='👀 Следую за <b>%s</b> (<code>%s</code>)\nСообщу о приходе 🏠 и уходе 👋'; T_w_follow_en='👀 Watching <b>%s</b> (<code>%s</code>)\nWill report arrival 🏠 and departure 👋'; T_w_follow_uk='👀 Слідкую за <b>%s</b> (<code>%s</code>)\nПовідомлю про прихід 🏠 і відхід 👋'
T_w_unfol_ru='🗑 Наблюдение за <b>%s</b> снято'; T_w_unfol_en='🗑 Stopped watching <b>%s</b>'; T_w_unfol_uk='🗑 Нагляд за <b>%s</b> знято'
T_p_home_ru='🏠 <b>%s</b> дома · %s'; T_p_home_en='🏠 <b>%s</b> is home · %s'; T_p_home_uk='🏠 <b>%s</b> вдома · %s'
T_p_away_ru='👋 <b>%s</b> ушёл · %s'; T_p_away_en='👋 <b>%s</b> left · %s'; T_p_away_uk='👋 <b>%s</b> пішов · %s'
T_g_pre_ru='гость'; T_g_pre_en='guest'; T_g_pre_uk='гість'
T_mon_hdr_ru='<b>👁 Мониторинг хостов:</b>'; T_mon_hdr_en='<b>👁 Host monitoring:</b>'; T_mon_hdr_uk='<b>👁 Моніторинг хостів:</b>'
T_mon_empty_ru='📭 Список пуст. Добавить: /mon add nas.local NAS'; T_mon_empty_en='📭 List empty. Add: /mon add nas.local NAS'; T_mon_empty_uk='📭 Список порожній. Додати: /mon add nas.local NAS'
T_mon_addfmt_ru='Формат: /mon add 192.168.1.50 NAS'; T_mon_addfmt_en='Format: /mon add 192.168.1.50 NAS'; T_mon_addfmt_uk='Формат: /mon add 192.168.1.50 NAS'
T_mon_fol_ru='👁 Следю за <code>%s</code> (%s) — сообщу о падении/восстановлении'; T_mon_fol_en='👁 Watching <code>%s</code> (%s) — will report down/up'; T_mon_fol_uk='👁 Слідкую за <code>%s</code> (%s) — повідомлю про падіння/відновлення'
T_mon_del_ru='🗑 Убрал из мониторинга'; T_mon_del_en='🗑 Removed from monitoring'; T_mon_del_uk='🗑 Прибрано з моніторингу'
T_h_down_ru='🔴 <b>%s</b> НЕДОСТУПЕН · <code>%s</code> · %s'; T_h_down_en='🔴 <b>%s</b> DOWN · <code>%s</code> · %s'; T_h_down_uk='🔴 <b>%s</b> НЕДОСТУПНИЙ · <code>%s</code> · %s'
T_h_up_ru='🟢 <b>%s</b> снова в сети · <code>%s</code> · %s'; T_h_up_en='🟢 <b>%s</b> back online · <code>%s</code> · %s'; T_h_up_uk='🟢 <b>%s</b> знову в мережі · <code>%s</code> · %s'
T_ai_nokey_ru='🔑 AI-ключей нет. Надішліть боту: /key gsk_… (Groq), /key sk-or-v1… (OpenRouter) або будь-який інший ключ (Gemini). Або LuCI → Services → Telegram Bot.'; T_ai_nokey_en='🔑 No AI keys yet. Send: /key gsk_… (Groq), /key sk-or-v1… (OpenRouter) or any other key (Gemini). Or LuCI → Services → Telegram Bot.'; T_ai_nokey_uk='🔑 AI-ключів немає. Надішліть боту: /key gsk_… (Groq), /key sk-or-v1… (OpenRouter) або будь-який інший ключ (Gemini). Або LuCI → Services → Telegram Bot.'
T_ai_think_ru='🤔 Думаю...'; T_ai_think_en='🤔 Thinking...'; T_ai_think_uk='🤔 Думаю...'
T_ai_hint_ru='🤖 Напишите вопрос текстом. Выйти: /ai off'; T_ai_hint_en='🤖 Type your question. Exit: /ai off'; T_ai_hint_uk='🤖 Напишіть питання текстом. Вихід: /ai off'
T_ai_entered_ru='🤖 <b>AI-чат включён</b>\nПишите вопрос текстом — я вижу состояние роутера\nи могу выполнять команды (настройки — только с подтверждением).\nВыйти: /ai off или кнопкой ниже.'
T_ai_entered_en='🤖 <b>AI chat enabled</b>\nJust type your question - I see router state\nand can run commands (config changes need confirmation).\nExit: /ai off or the button below.'
T_ai_entered_uk='🤖 <b>AI-чат увімкнено</b>\nПишіть питання текстом — я бачу стан роутера\nі можу виконувати команди (налаштування — лише з підтвердженням).\nВихід: /ai off або кнопкою нижче.'
T_ai_exitmsg_ru='⛔️ Вышел из AI-чата. Обычное меню:'; T_ai_exitmsg_en='⛔️ Exited AI chat. Regular menu:'; T_ai_exitmsg_uk='⛔️ Вийшов з AI-чату. Звичайне меню:'
T_ai_exit_ru='⛔️ Вышел из AI-чата.'; T_ai_exit_en='⛔️ Exited AI chat.'; T_ai_exit_uk='⛔️ Вийшов з AI-чату.'
T_ai_confirm_ru='🤖 Хочу выполнить:\n<code>%s</code>\nЭто меняет настройки роутера.'; T_ai_confirm_en='🤖 I want to run:\n<code>%s</code>\nThis changes router settings.'; T_ai_confirm_uk='🤖 Хочу виконати:\n<code>%s</code>\nЦе змінює налаштування роутера.'
T_ai_conflbl_ru='Подтвердите:'; T_ai_conflbl_en='Confirm:'; T_ai_conflbl_uk='Підтвердіть:'
T_ai_done_ru='✅ Выполнено: <code>%s</code>\n\nРезультат:\n<code>%s</code>'; T_ai_done_en='✅ Done: <code>%s</code>\n\nResult:\n<code>%s</code>'; T_ai_done_uk='✅ Виконано: <code>%s</code>\n\nРезультат:\n<code>%s</code>'
T_ai_pendnone_ru='Нет отложенной команды.'; T_ai_pendnone_en='No pending command.'; T_ai_pendnone_uk='Немає відкладеної команди.'
T_ai_cancelled_ru='❌ Отменено.'; T_ai_cancelled_en='❌ Cancelled.'; T_ai_cancelled_uk='❌ Скасовано.'
T_ai_noans_ru='Не получил ответ модели. Детали: /etc/tg-bot/lasterr'; T_ai_noans_en='No answer from the model. Details: /etc/tg-bot/lasterr'; T_ai_noans_uk='Не отримав відповіді моделі. Деталі: /etc/tg-bot/lasterr'
T_pend_hint_ru='⏳ Команда ещё ждёт подтверждения:\n<code>%s</code>\nНажмите ✅ или отправьте /ok — тогда выполню.'; T_pend_hint_en='⏳ Command is awaiting confirmation:\n<code>%s</code>\nTap ✅ or send /ok to run it.'; T_pend_hint_uk='⏳ Команда ще чекає підтвердження:\n<code>%s</code>\nНатисніть ✅ або надішліть /ok — тоді виконаю.'
  T_ai_chainfail_ru='⚠️ Все AI-модели сейчас недоступны (лимиты/сеть). Попробуйте через ~10 минут — цепочка сама переключится на резерв.'; T_ai_chainfail_en='⚠️ All AI models are unavailable right now (limits/network). Try again in ~10 minutes — the chain will fail over automatically.'; T_ai_chainfail_uk='⚠️ Усі AI-моделі зараз недоступні (ліміти/мережа). Спробуйте через ~10 хвилин — ланцюг сам переключиться на резерв.'
  T_san_rej_ru='🚫 Отклонено: в команде запрещённые конструкции ($(), `, ;, одиночный &, невидимые символы). Переформулируйте без них.'; T_san_rej_en='🚫 Rejected: command contains forbidden constructs ($(), backticks, ;, lone &, invisible chars). Please rephrase.'; T_san_rej_uk='🚫 Відхилено: у команді заборонені конструкції ($(), `, ;, поодинокий &, невидимі символи). Переформулюйте без них.'
  T_mdl_title_ru='⚙️ <b>AI-модель</b>\n\nОсновная: <code>%s</code>\nРезерв: <code>%s</code>\nЦепочка Groq: <code>%s</code>\n\nВыберите основную модель — применяется сразу, без рестарта:'; T_mdl_title_en='⚙️ <b>AI model</b>\n\nPrimary: <code>%s</code>\nAlt: <code>%s</code>\nGroq chain: <code>%s</code>\n\nPick the primary model — applies instantly, no restart:'; T_mdl_title_uk='⚙️ <b>AI-модель</b>\n\nОсновна: <code>%s</code>\nРезерв: <code>%s</code>\nЛанцюг Groq: <code>%s</code>\n\nВиберіть основну модель — застосовується одразу, без рестарту:'
  T_mdl_set_ru='✅ Основная модель: %s'; T_mdl_set_en='✅ Primary model: %s'; T_mdl_set_uk='✅ Основна модель: %s'
  T_c_mdl_ru='сменить AI-модель'; T_c_mdl_en='switch AI model'; T_c_mdl_uk='змінити AI-модель'
  T_c_key_ru='добавить AI-ключ'; T_c_key_en='add AI key'; T_c_key_uk='додати AI-ключ'
T_cmd_run_ru='⚙️ Выполняю: <code>%s</code>'; T_cmd_run_en='⚙️ Running: <code>%s</code>'; T_cmd_run_uk='⚙️ Виконую: <code>%s</code>'
T_rb_arm_ru='⚠️ Подтвердите: /reboot yes (или кнопкой ниже 👇)'; T_rb_arm_en='⚠️ Confirm: /reboot yes (or the button below 👇)'; T_rb_arm_uk='⚠️ Підтвердіть: /reboot yes (або кнопкою нижче 👇)'
T_rb_menu_ru='🤖 Меню:'; T_rb_menu_en='🤖 Menu:'; T_rb_menu_uk='🤖 Меню:'
T_rb_sure_ru='⚠️ Точно перезагрузить роутер?'; T_rb_sure_en='⚠️ Really reboot the router?'; T_rb_sure_uk='⚠️ Точно перезавантажити роутер?'
T_rb_going_ru='🔄 Перезагружаюсь! Вернусь через ~1-2 минуты.'; T_rb_going_en='🔄 Rebooting! Back in ~1-2 minutes.'; T_rb_going_uk='🔄 Перезавантажуюсь! Повернуся через ~1-2 хвилини.'
T_rb_need_ru='⚠️ Сначала /reboot, затем /reboot yes'; T_rb_need_en='⚠️ First /reboot, then /reboot yes'; T_rb_need_uk='⚠️ Спочатку /reboot, потім /reboot yes'
T_rb_exp_ru='⚠️ Время подтверждения истекло. Нажмите ⚡️ Ребут заново.'; T_rb_exp_en='⚠️ Confirmation expired. Press ⚡️ Reboot again.'; T_rb_exp_uk='⚠️ Час підтвердження минув. Натисніть ⚡️ Ребут знову.'
T_wan_run_ru='🔄 Перезапускаю WAN...'; T_wan_run_en='🔄 Restarting WAN...'; T_wan_run_uk='🔄 Перезапускаю WAN...'
T_pulse_ru='<h3>✅ Роутер работает</h3><table bordered striped><tr><td>⏱ Аптайм</td><td><code>%s</code></td></tr><tr><td>🔗 Интернет</td><td>%s</td></tr></table><footer>🕐 %s · пульс каждый час; время замерло — роутер был выключен</footer>'
T_pulse_en='<h3>✅ Router is up</h3><table bordered striped><tr><td>⏱ Uptime</td><td><code>%s</code></td></tr><tr><td>🔗 Internet</td><td>%s</td></tr></table><footer>🕐 %s · hourly heartbeat; stale time = router was down</footer>'
T_pulse_uk='<h3>✅ Роутер працює</h3><table bordered striped><tr><td>⏱ Аптайм</td><td><code>%s</code></td></tr><tr><td>🔗 Інтернет</td><td>%s</td></tr></table><footer>🕐 %s · пульс щогодини; час зупинився — роутер був вимкнений</footer>'
T_c_status_ru='📊 Статус роутера'; T_c_status_en='📊 Router status'; T_c_status_uk='📊 Статус роутера'
T_c_dev_ru='📱 Устройства в сети'; T_c_dev_en='📱 Network devices'; T_c_dev_uk='📱 Пристрої в мережі'
T_c_wan_ru='🌐 Перезапустить интернет'; T_c_wan_en='🌐 Reconnect internet'; T_c_wan_uk='🌐 Перепідключити інтернет'
T_c_bk_ru='💾 Бэкап конфигов файлом'; T_c_bk_en='💾 Config backup file'; T_c_bk_uk='💾 Бекап конфігів файлом'
T_c_qr_ru='🔑 QR-код для Wi-Fi'; T_c_qr_en='🔑 Wi-Fi QR code'; T_c_qr_uk='🔑 QR-код для Wi-Fi'
T_c_scan_ru='📡 Скан сетей вокруг'; T_c_scan_en='📡 Scan nearby networks'; T_c_scan_uk='📡 Скан сусідніх мереж'
T_c_ai_ru='🤖 Спросить AI про роутер'; T_c_ai_en='🤖 Ask AI about the router'; T_c_ai_uk='🤖 Спитати AI про роутер'
T_c_alias_ru='🏷 Имя устройству: /alias IP Имя'; T_c_alias_en='🏷 Name a device: /alias IP Name'; T_c_alias_uk='🏷 Назва пристрою: /alias IP Назва'
T_c_watch_ru='👀 Слежка за людьми'; T_c_watch_en='👀 Watch people'; T_c_watch_uk='👀 Слідкування за людьми'
T_c_mon_ru='👁 Мониторинг хостов'; T_c_mon_en='👁 Host monitoring'; T_c_mon_uk='👁 Моніторинг хостів'
T_c_rb_ru='⚡️ Перезагрузка: /reboot yes'; T_c_rb_en='⚡️ Reboot: /reboot yes'; T_c_rb_uk='⚡️ Перезавантаження: /reboot yes'
T_c_help_ru='❓ Помощь'; T_c_help_en='❓ Help'; T_c_help_uk='❓ Довідка'
T_c_ailog_ru='🧾 Лог AI-диалогов'; T_c_ailog_en='🧾 AI dialog log'; T_c_ailog_uk='🧾 Лог AI-діалогів'
T_th_state_ru='Стан'; T_th_state_en='State'; T_th_state_uk='Стан'
T_th_name_ru='Назва'; T_th_name_en='Name'; T_th_name_uk='Назва'
T_d_offttl_ru='📍 Не в сети'; T_d_offttl_en='📍 Offline'; T_d_offttl_uk='📍 Не в мережі'
T_th_sig_ru='Сигнал'; T_th_sig_en='Signal'; T_th_sig_uk='Сигнал'
T_th_ch_ru='Канал'; T_th_ch_en='Channel'; T_th_ch_uk='Канал'
T_th_ssid_ru='SSID'; T_th_ssid_en='SSID'; T_th_ssid_uk='SSID'
T_d_hdr2_ru='<h3>📶 Устройства · 🟢 %s из %s</h3>'; T_d_hdr2_en='<h3>📶 Devices · 🟢 %s of %s</h3>'; T_d_hdr2_uk='<h3>📶 Пристрої · 🟢 %s із %s</h3>'
T_d_offttl_ru='<p>📍 Не в сети (%s)</p>'; T_d_offttl_en='<p>📍 Offline (%s)</p>'; T_d_offttl_uk='<p>📍 Не в мережі (%s)</p>'
T_ai_429_ru='⏳ Добова квота безкоштовних запитів OpenRouter вичерпана (50/день). Спробуйте после сброса лимита или добавьте кредиты на openrouter.ai.'
T_ai_429_en='⏳ OpenRouter free daily quota exhausted (50/day). Try after the reset or add credits at openrouter.ai.'
T_ai_429_uk='⏳ Добову квоту безкоштовних запитів OpenRouter вичерпано (50/день). Спробуйте після скидання ліміту або додайте кредити на openrouter.ai.'

# --- розширене меню: розділи ---
T_btn_wifi_ru='📶 Wi-Fi'; T_btn_wifi_en='📶 Wi-Fi'; T_btn_wifi_uk='📶 Wi-Fi'
T_btn_fw_ru='🛡 Файрвол'; T_btn_fw_en='🛡 Firewall'; T_btn_fw_uk='🛡 Фаєрвол'
T_btn_dg_ru='🔧 Диагностика'; T_btn_dg_en='🔧 Diagnostics'; T_btn_dg_uk='🔧 Діагностика'
T_btn_sys_ru='⚙️ Система'; T_btn_sys_en='⚙️ System'; T_btn_sys_uk='⚙️ Система'
T_w_title_ru='📶 <b>Wi-Fi и сети</b>\nВыберите действие:'; T_w_title_en='📶 <b>Wi-Fi & networks</b>\nPick an action:'; T_w_title_uk='📶 <b>Wi-Fi і мережі</b>\nОберіть дію:'
T_f_title_ru='🛡 <b>Файрвол</b>\nВыберите действие:'; T_f_title_en='🛡 <b>Firewall</b>\nPick an action:'; T_f_title_uk='🛡 <b>Фаєрвол</b>\nОберіть дію:'
T_d_title_ru='🔧 <b>Диагностика</b>\nВыберите действие:'; T_d_title_en='🔧 <b>Diagnostics</b>\nPick an action:'; T_d_title_uk='🔧 <b>Діагностика</b>\nОберіть дію:'
T_s_title_ru='⚙️ <b>Система</b>\nВыберите действие:'; T_s_title_en='⚙️ <b>System</b>\nPick an action:'; T_s_title_uk='⚙️ <b>Система</b>\nОберіть дію:'
T_rbky_ru='✅ Да, откатить!'; T_rbky_en='✅ Yes, rollback!'; T_rbky_uk='✅ Так, відкотити!'
T_rbk_arm_ru='⚠️ Откатить конфиги к последнему снимку?\nЭто перезапишет network/wireless/dhcp/firewall/system/sqm.'; T_rbk_arm_en='⚠️ Rollback configs to the last snapshot?\nThis overwrites network/wireless/dhcp/firewall/system/sqm.'; T_rbk_arm_uk='⚠️ Відкотити конфіги до останнього знімка?\nЦе перезапише network/wireless/dhcp/firewall/system/sqm.'
T_rbk_none_ru='↩️ Снимков ещё нет — откатывать не из чего'; T_rbk_none_en='↩️ No snapshots yet — nothing to roll back to'; T_rbk_none_uk='↩️ Знімків ще немає — відкатувати не з чого'
T_rbk_ok_ru='↩️ Конфиги откатаны к снимку %s'; T_rbk_ok_en='↩️ Configs rolled back to snapshot %s'; T_rbk_ok_uk='↩️ Конфіги відкотто до знімка %s'
T_rbk_exp_ru='⚠️ Время подтверждения истекло. Нажмите ↩️ Rollback заново.'; T_rbk_exp_en='⚠️ Confirmation expired. Press ↩️ Rollback again.'; T_rbk_exp_uk='⚠️ Час підтвердження минув. Натисніть ↩️ Rollback знову.'
T_c_topo_ru='🧭 Топология сети: /topo IP Метка'; T_c_topo_en='🧭 Network topology: /topo IP Label'; T_c_topo_uk='🧭 Топологія мережі: /topo IP Мітка'
T_c_rback_ru='↩️ Откат конфигов к снимку'; T_c_rback_en='↩️ Rollback configs to snapshot'; T_c_rback_uk='↩️ Відкат конфігів до знімка'
T_c_wifi_ru='📶 Керування Wi-Fi'; T_c_wifi_en='📶 Wi-Fi control'; T_c_wifi_uk='📶 Керування Wi-Fi'

# --- Wi-Fi керування (фаза 2) ---
T_wf_pick_ru='📶 Оберіть мережу:'; T_wf_pick_en='📶 Pick a network:'; T_wf_pick_uk='📶 Оберіть мережу:'
T_wf_none_ru='📭 Wi-Fi интерфейсы не найдены'; T_wf_none_en='📭 No Wi-Fi interfaces found'; T_wf_none_uk='📭 Wi-Fi інтерфейси не знайдені'
T_wf_hdr_ru='%s <b>%s</b>\nSSID: <code>%s</code>\n🔑 Пароль: <code>%s</code>\nКанал: <code>%s</code> · Потужність: <code>%s</code>\n\nЩо змінити?'
T_wf_hdr_en='%s <b>%s</b>\nSSID: <code>%s</code>\n🔑 Password: <code>%s</code>\nChannel: <code>%s</code> · TX power: <code>%s</code>\n\nWhat to change?'
T_wf_hdr_uk='%s <b>%s</b>\nSSID: <code>%s</code>\n🔑 Пароль: <code>%s</code>\nКанал: <code>%s</code> · Потужність: <code>%s</code>\n\nЩо змінити?'
T_wf_b_key_ru='🔑 Пароль'; T_wf_b_key_en='🔑 Password'; T_wf_b_key_uk='🔑 Пароль'
T_wf_b_ssid_ru='✏️ SSID'; T_wf_b_ssid_en='✏️ SSID'; T_wf_b_ssid_uk='✏️ SSID'
T_wf_b_ch_ru='📶 Канал'; T_wf_b_ch_en='📶 Channel'; T_wf_b_ch_uk='📶 Канал'
T_wf_b_pwr_ru='💪 Потужність'; T_wf_b_pwr_en='💪 TX power'; T_wf_b_pwr_uk='💪 Потужність'
T_wf_b_tgl_ru='⏻ Вкл/Выкл'; T_wf_b_tgl_en='⏻ On/Off'; T_wf_b_tgl_uk='⏻ Увімк/Вимк'
T_wf_ask_key_ru='🔑 Надішліть новий пароль Wi-Fi (від 8 до 63 символів):'; T_wf_ask_key_en='🔑 Send the new Wi-Fi password (8-63 chars):'; T_wf_ask_key_uk='🔑 Надішліть новий пароль Wi-Fi (від 8 до 63 символів):'
T_wf_ask_ssid_ru='✏️ Надішліть новий SSID (до 32 символів):'; T_wf_ask_ssid_en='✏️ Send the new SSID (up to 32 chars):'; T_wf_ask_ssid_uk='✏️ Надішліть новий SSID (до 32 символів):'
T_wf_ask_ch_ru='📶 Надішліть номер каналу або слово auto:'; T_wf_ask_ch_en='📶 Send a channel number or the word auto:'; T_wf_ask_ch_uk='📶 Надішліть номер каналу або слово auto:'
T_wf_bad_key_ru='❌ Пароль має бути 8-63 символи. Спробуйте ще раз:'; T_wf_bad_key_en='❌ Password must be 8-63 chars. Try again:'; T_wf_bad_key_uk='❌ Пароль має бути 8-63 символи. Спробуйте ще раз:'
T_wf_bad_ssid_ru='❌ SSID має бути 1-32 символи. Спробуйте ще раз:'; T_wf_bad_ssid_en='❌ SSID must be 1-32 chars. Try again:'; T_wf_bad_ssid_uk='❌ SSID має бути 1-32 символи. Спробуйте ще раз:'
T_wf_bad_ch_ru='❌ Канал — число або слово auto. Спробуйте ще раз:'; T_wf_bad_ch_en='❌ Channel must be a number or auto. Try again:'; T_wf_bad_ch_uk='❌ Канал — число або слово auto. Спробуйте ще раз:'
T_wf_conf_ru='📶 Застосувати зміни Wi-Fi?\n<code>%s</code>\nМережа перезавантажиться (~5 с).'
T_wf_conf_en='📶 Apply Wi-Fi changes?\n<code>%s</code>\nThe network will reload (~5 s).'
T_wf_conf_uk='📶 Застосувати зміни Wi-Fi?\n<code>%s</code>\nМережа перезавантажиться (~5 с).'
T_wf_b_nets_ru='📡 Мои сети'; T_wf_b_nets_en='📡 My networks'; T_wf_b_nets_uk='📡 Мої мережі'

# --- Фаєрвол (фаза 3) ---
T_f2_title_ru='🛡 <b>Файрвол</b>\nВыберите действие:'; T_f2_title_en='🛡 <b>Firewall</b>\nPick an action:'; T_f2_title_uk='🛡 <b>Фаєрвол</b>\nОберіть дію:'
T_fw_btn_pf_ru='🔀 Портфорворди'; T_fw_btn_pf_en='🔀 Port forwards'; T_fw_btn_pf_uk='🔀 Проброси портів'
T_fw_none_ru='📭 Портфорвордов нет.\nДобавить: кнопка ➕ в разделе 🛡 Файрвол'; T_fw_none_en='📭 No port forwards.\nAdd one via the ➕ button in 🛡 Firewall'; T_fw_none_uk='📭 Пробросів портів немає.\nДодайте кнопкою ➕ у розділі 🛡 Фаєрвол'
T_fw_hdr_ru='<b>🔀 Портфорворды (WAN)</b>\nТап по правилу — удалить:'; T_fw_hdr_en='<b>🔀 Port forwards (WAN)</b>\nTap a rule to delete:'; T_fw_hdr_uk='<b>🔀 Проброси портів (WAN)</b>\nТап по правилу — видалити:'
T_fw_addbtn_ru='➕ Додати проброс'; T_fw_addbtn_en='➕ Add forward'; T_fw_addbtn_uk='➕ Додати проброс'
T_fw_ask_proto_ru='🔀 Оберіть протокол:'; T_fw_ask_proto_en='🔀 Pick a protocol:'; T_fw_ask_proto_uk='🔀 Оберіть протокол:'
T_fw_ask_eport_ru='🌐 Надішліть зовнішній порт WAN (1-65535):'; T_fw_ask_eport_en='🌐 Send the external WAN port (1-65535):'; T_fw_ask_eport_uk='🌐 Надішліть зовнішній порт WAN (1-65535):'
T_fw_bad_eport_ru='❌ Потрібен порт 1-65535. Спробуйте ще раз:'; T_fw_bad_eport_en='❌ Need a port 1-65535. Try again:'; T_fw_bad_eport_uk='❌ Потрібен порт 1-65535. Спробуйте ще раз:'
T_fw_ask_dip_ru='🏠 Надішліть внутрішню IP-адресу (наприклад 192.168.1.50):'; T_fw_ask_dip_en='🏠 Send the internal IP (e.g. 192.168.1.50):'; T_fw_ask_dip_uk='🏠 Надішліть внутрішню IP-адресу (наприклад 192.168.1.50):'
T_fw_bad_dip_ru='❌ Це не схоже на IPv4-адресу. Спробуйте ще раз:'; T_fw_bad_dip_en="❌ That doesn't look like an IPv4 address. Try again:"; T_fw_bad_dip_uk='❌ Це не схоже на IPv4-адресу. Спробуйте ще раз:'
T_fw_ask_dport_ru='🎯 Надішліть внутрішній порт, або - якщо той самий:'; T_fw_ask_dport_en='🎯 Send the internal port, or - to keep the same:'; T_fw_ask_dport_uk='🎯 Надішліть внутрішній порт, або - якщо той самий:'
T_fwd_conf_ru='🛡 Застосувати зміну фаєрвола?\n<code>%s</code>'
T_fwd_conf_en='🛡 Apply firewall change?\n<code>%s</code>'
T_fwd_conf_uk='🛡 Застосувати зміну фаєрвола?\n<code>%s</code>'

# --- Діагностика (фаза 4) ---
T_dg_btn_ping_ru='🏓 Ping'; T_dg_btn_ping_en='🏓 Ping'; T_dg_btn_ping_uk='🏓 Ping'
T_dg_btn_trace_ru='🛰 Traceroute'; T_dg_btn_trace_en='🛰 Traceroute'; T_dg_btn_trace_uk='🛰 Traceroute'
T_dg_btn_ns_ru='🔎 NSLookup'; T_dg_btn_ns_en='🔎 NSLookup'; T_dg_btn_ns_uk='🔎 NSLookup'
T_dg_btn_lr_ru='📜 Системный лог'; T_dg_btn_lr_en='📜 System log'; T_dg_btn_lr_uk='📜 Системний лог'
T_dg_btn_dm_ru='🧨 Лог ядра'; T_dg_btn_dm_en='🧨 Kernel log'; T_dg_btn_dm_uk='🧨 Лог ядра'
T_dg_ask_ru='🎯 Надішліть хост або IP для перевірки:'; T_dg_ask_en='🎯 Send a host or IP to check:'; T_dg_ask_uk='🎯 Надішліть хост або IP для перевірки:'
T_dg_bad_ru='❌ Не схоже на адресу/хост (дозволені літери, цифри, . -). Спробуйте ще раз:'; T_dg_bad_en="❌ Doesn't look like a host/IP (letters, digits, . - only). Try again:"; T_dg_bad_uk='❌ Не схоже на адресу/хост (лише літери, цифри, . -). Спробуйте ще раз:'
T_dg_doing_ru='⏳ Виконую <code>%s %s</code> — результат надішлю окремим повідомленням.'; T_dg_doing_en='⏳ Running <code>%s %s</code> — result will arrive in a separate message.'; T_dg_doing_uk='⏳ Виконую <code>%s %s</code> — результат надішлю окремим повідомленням.'
T_dg_logsent_ru='📜 Лог прикріплено файлом.'; T_dg_logsent_en='📜 Log attached as a file.'; T_dg_logsent_uk='📜 Лог прикріплено файлом.'

# --- Система: пакети і SSH-ключі (фаза 5) ---
T_s_btn_pkg_ru='📦 Пакеты'; T_s_btn_pkg_en='📦 Packages'; T_s_btn_pkg_uk='📦 Пакети'
T_s_btn_ssh_ru='🔑 SSH-ключи'; T_s_btn_ssh_en='🔑 SSH keys'; T_s_btn_ssh_uk='🔑 SSH-ключі'
T_pk_ask_ru='📦 Надішліть назву пакета (наприклад nlbwmon):'; T_pk_ask_en='📦 Send a package name (e.g. nlbwmon):'; T_pk_ask_uk='📦 Надішліть назву пакета (наприклад nlbwmon):'
T_pk_bad_ru='❌ Назва пакета: літери, цифри, . _ -. Спробуйте ще раз:'; T_pk_bad_en="❌ Package name: letters, digits, . _ - only. Try again:"; T_pk_bad_uk='❌ Назва пакета: літери, цифри, . _ -. Спробуйте ще раз:'
T_ssh_add_ru='➕ Додати ключ'; T_ssh_add_en='➕ Add key'; T_ssh_add_uk='➕ Додати ключ'
T_ssh_ask_ru='🔑 Надішліть публічний SSH-ключ одним рядком (починається зі ssh-ed25519 або ssh-rsa):'; T_ssh_ask_en='🔑 Send a public SSH key as one line (starts with ssh-ed25519 or ssh-rsa):'; T_ssh_ask_uk='🔑 Надішліть публічний SSH-ключ одним рядком (починається зі ssh-ed25519 або ssh-rsa):'
T_ssh_bad_ru='❌ Це не схоже на публічний SSH-ключ (очікую ssh-ed25519/ssh-rsa + base64).'; T_ssh_bad_en="❌ Doesn't look like a public SSH key (expected ssh-ed25519/ssh-rsa + base64)."; T_ssh_bad_uk='❌ Це не схоже на публічний SSH-ключ (очікую ssh-ed25519/ssh-rsa + base64).'

# --- токен-оптимізація агента (фази A-G) ---
T_c_usage_ru='📈 Витрати AI-токенів за добу'; T_c_usage_en='📈 AI token usage today'; T_c_usage_uk='📈 Витрати AI-токенів за добу'
T_c_cancel_ru='🛑 Скасувати очікування/дію'; T_c_cancel_en='🛫 Cancel pending action'; T_c_cancel_uk='🛑 Скасувати очікування/дію'
T_cancel_ok_ru='🛑 Скасовано: очікувані підтвердження, контекст вводу і фонові задачі скинуто.'; T_cancel_ok_en='🛑 Cancelled: pending confirmations, input context and background tasks cleared.'; T_cancel_ok_uk='🛑 Скасовано: очікувані підтвердження, контекст вводу і фонові задачі скинуто.'
T_batch_mut_ru='🚫 У батчі є команда зміни налаштувань — мутації виконуються ТІЛЬКИ по одній з підтвердженням. Надішліть запит ще раз: спершу читання, потім зміну окремо.'; T_batch_mut_en='🚫 The batch contains a settings change — mutations run ONLY one at a time with confirmation. Please rephrase: reads first, then the change separately.'; T_batch_mut_uk='🚫 У батчі є команда зміни налаштувань — мутації виконуються ТІЛЬКИ по одній з підтвердженням. Надішліть запит ще раз: спершу читання, потім зміну окремо.'
T_plan_lbl_ru='📋 План задачі:'; T_plan_lbl_en='📋 Task plan:'; T_plan_lbl_uk='📋 План задачі:'
T_usage_none_ru='📊 Записів про витрати ще немає (toklog порожній).\nДані зʼявляються після перших звернень до AI.'; T_usage_none_en='📊 No usage records yet (empty toklog).\nData appears after your first AI queries.'; T_usage_none_uk='📊 Записів про витрати ще немає (toklog порожній).\nДані зʼявляються після перших звернень до AI.'
T_q_temp_ru='🌡 <b>Температура</b>\n%s'; T_q_temp_en='🌡 <b>Temperature</b>\n%s'; T_q_temp_uk='🌡 <b>Температура</b>\n%s'
T_q_res_ru='🧠 <b>Ресурси</b>\nRAM: %s\nДиск /: %s\nLoad: %s'; T_q_res_en='🧠 <b>Resources</b>\nRAM: %s\nDisk /: %s\nLoad: %s'; T_q_res_uk='🧠 <b>Ресурси</b>\nRAM: %s\nДиск /: %s\nLoad: %s'
T_q_pubip_ru='🌍 <b>Публічний IP</b>: <code>%s</code>%s'; T_q_pubip_en='🌍 <b>Public IP</b>: <code>%s</code>%s'; T_q_pubip_uk='🌍 <b>Публічний IP</b>: <code>%s</code>%s'
T_q_cgnat_ru='\n⚠️ CGNAT — адреса приватна, проброс портів ззовні не працює'; T_q_cgnat_en='\n⚠️ CGNAT — private address, port forwarding from outside will not work'; T_q_cgnat_uk='\n⚠️ CGNAT — приватна адреса, проброс портів ззовні не працюватиме'

# --- VPN-розділ: Cloudflare WARP ---
T_btn_vpn_ru='🌐 VPN'; T_btn_vpn_en='🌐 VPN'; T_btn_vpn_uk='🌐 VPN'
T_vpn_title_ru='🌐 <b>VPN · Cloudflare WARP</b>\nПриватний вихід через WireGuard-тунель до Cloudflare.\nОбхід блокувань по IP; MTU 1280; безкоштовно.'; T_vpn_title_en='🌐 <b>VPN · Cloudflare WARP</b>\nPrivate exit via a WireGuard tunnel to Cloudflare.\nIP-block bypass; MTU 1280; free.'; T_vpn_title_uk='🌐 <b>VPN · Cloudflare WARP</b>\nПриватний вихід через WireGuard-тунель до Cloudflare.\nОбхід блокувань по IP; MTU 1280; безкоштовно.'
T_v_status_ru='📊 Статус'; T_v_status_en='📊 Status'; T_v_status_uk='📊 Статус'
T_v_connect_ru='⚡️ Підключити'; T_v_connect_en='⚡️ Set up'; T_v_connect_uk='⚡️ Підключити'
T_v_aon_ru='🟢 Весь трафік'; T_v_aon_en='🟢 All traffic'; T_v_aon_uk='🟢 Весь трафік'
T_v_aoff_ru='⏸ Припинити'; T_v_aoff_en='⏸ Stop routing'; T_v_aoff_uk='⏸ Припинити'
T_v_delete_ru='🗑 Видалити WARP'; T_v_delete_en='🗑 Remove WARP'; T_v_delete_uk='🗑 Видалити WARP'
T_v_go_ru='✅ Так, створити'; T_v_go_en='✅ Yes, create'; T_v_go_uk='✅ Так, створити'
T_v_noconf_ru='📭 WARP ще не налаштований.\nНатисніть ⚡️ Підключити — бот сам встановить wireguard-tools, зареєструє тунель на серверах Cloudflare і створить конфіг (без перехоплення трафіку).'; T_v_noconf_en='📭 WARP is not configured yet.\nTap ⚡️ Set up — the bot will install wireguard-tools, register the tunnel with Cloudflare and create the config (no traffic rerouting).'; T_v_noconf_uk='📭 WARP ще не налаштований.\nНатисніть ⚡️ Підключити — бот сам встановить wireguard-tools, зареєструє тунель на серверах Cloudflare і створить конфіг (без перехоплення трафіку).'
T_v_reg_ask_ru='⚡️ Створити WARP-тунель?\n\n• встановиться пакет <code>wireguard-tools</code>\n• реєстрація через публічний API Cloudflare (ключі лишаться на роутері)\n• новий інтерфейс <code>warp</code> БЕЗ зміни основного маршруту\n\n⚠️ Можливий короткий збій інтернету (~30 с) при першому запуску.'; T_v_reg_ask_en='⚡️ Create the WARP tunnel?\n\n• installs <code>wireguard-tools</code> package\n• registers via public Cloudflare API (keys stay on the router)\n• new <code>warp</code> interface WITHOUT changing the main route\n\n⚠️ A brief internet blip (~30 s) is possible on first run.'; T_v_reg_ask_uk='⚡️ Створити WARP-тунель?\n\n• встановиться пакет <code>wireguard-tools</code>\n• реєстрація через публічний API Cloudflare (ключі лишаться на роутері)\n• новий інтерфейс <code>warp</code> БЕЗ зміни основного маршруту\n\n⚠️ Можливий короткий збій інтернету (~30 с) при першому запуску.'
T_v_reg_run_ru='⏳ Реєстрація та налаштування WARP у фоні (до ~2 хв)…'; T_v_reg_run_en='⏳ Registering and configuring WARP in background (~2 min)…'; T_v_reg_run_uk='⏳ Реєстрація та налаштування WARP у фоні (до ~2 хв)…'
T_v_aon_warn_ru='⚠️ Пустити ВЕСЬ трафік через WARP?\nЯкщо тунель упаде — інтернет зникне до відкату.\nРекомендую 🔒 зі страховкою (авто-відкат 90с).\n<code>%s</code>'; T_v_aon_warn_en='⚠️ Route ALL traffic via WARP?\nIf the tunnel dies, internet goes down until rollback.\n🔒 Safety-net recommended (auto-rollback 90s).\n<code>%s</code>'; T_v_aon_warn_uk='⚠️ Пустити ВЕСЬ трафік через WARP?\nЯкщо тунель впаде — інтернет зникне до відкату.\nРекомендую 🔒 зі страховкою (авто-відкат 90с).\n<code>%s</code>'
T_v_del_ask_ru='🗑 Видалити WARP повністю?\n(інтерфейс, peer, зону файрвола, ключі)'; T_v_del_ask_en='🗑 Remove WARP completely?\n(interface, peer, firewall zone, keys)'; T_v_del_ask_uk='🗑 Видалити WARP повністю?\n(інтерфейс, peer, зону файрвола, ключі)'
T_v_s_on_ru='🟢 Тунель активний'; T_v_s_on_en='🟢 Tunnel active'; T_v_s_on_uk='🟢 Тунель активний'
T_v_s_off_ru='🔴 Немає handshake'; T_v_s_off_en='🔴 No handshake'; T_v_s_off_uk='🔴 Немає handshake'
T_v_s_nc_ru='📭 не налаштовано'; T_v_s_nc_en='📭 not configured'; T_v_s_nc_uk='📭 не налаштовано'
T_v_mode_all_ru='режим: весь трафік через WARP'; T_v_mode_all_en='mode: all traffic via WARP'; T_v_mode_all_uk='режим: весь трафік через WARP'
T_v_mode_idle_ru='режим: тунель є, трафік не перехоплюється'; T_v_mode_idle_en='mode: tunnel up, traffic not routed'; T_v_mode_idle_uk='режим: тунель є, трафік не перехоплюється'
T_v_mode_pbr_ru='режим: тільки заблоковані через WARP (PBR)'; T_v_mode_pbr_en='mode: blocked-only via WARP (PBR)'; T_v_mode_pbr_uk='режим: тільки заблоковані через WARP (PBR)'

# --- WARP-оптимізатор: MTU-тестер і пінг endpoint-ів ---
T_v_btn_mtu_ru='📏 MTU-тест'; T_v_btn_mtu_en='📏 MTU test'; T_v_btn_mtu_uk='📏 MTU-тест'
T_v_btn_ep_ru='📡 Пінг endpoint'; T_v_btn_ep_en='📡 Endpoint ping'; T_v_btn_ep_uk='📡 Пінг endpoint'
T_v_mtu_run_ru='⏳ Тестую MTU 1420/1400/1380/1280 (~1.5 хв).\n⚠️ Інтернет мигатиме по ~10 с на кожного кандидата. Результат надішлю окремо.'; T_v_mtu_run_en='⏳ Testing MTU 1420/1400/1380/1280 (~1.5 min).\n⚠️ Internet will blip ~10 s per candidate. Result arrives separately.'; T_v_mtu_run_uk='⏳ Тестую MTU 1420/1400/1380/1280 (~1.5 хв).\n⚠️ Інтернет мигатиме по ~10 с на кожного кандидата. Результат надішлю окремо.'
T_v_ep_run_ru='⏳ Пінгую 6 endpoint-ів Cloudflare (~15 с)…'; T_v_ep_run_en='⏳ Pinging 6 Cloudflare endpoints (~15 s)…'; T_v_ep_run_uk='⏳ Пінгую 6 endpoint-ів Cloudflare (~15 с)…'
T_v_mtu_tbl_ru='📏 MTU-тест (завантажено за 8 с через тунель):'; T_v_mtu_tbl_en='📏 MTU test (downloaded in 8 s via tunnel):'; T_v_mtu_tbl_uk='📏 MTU-тест (завантажено за 8 с через тунель):'
T_v_ep_tbl_ru='📡 Пінг endpoint-ів Cloudflare:'; T_v_ep_tbl_en='📡 Cloudflare endpoint ping:'; T_v_ep_tbl_uk='📡 Пінг endpoint-ів Cloudflare:'
T_v_apply_best_ru='✅ Застосувати %s'; T_v_apply_best_en='✅ Apply %s'; T_v_apply_best_uk='✅ Застосувати %s'
T_v_mtu_fail_ru='❌ Жоден MTU не дав handshake — повернув безпечний 1280.'; T_v_mtu_fail_en='❌ No MTU produced a handshake — restored safe 1280.'; T_v_mtu_fail_uk='❌ Жоден MTU не дав handshake — повернув безпечний 1280.'
T_v_ping_fail_ru='❌ ICMP до Cloudflare заблоковано провайдером — пінг-тест неможливий.'; T_v_ping_fail_en="❌ ICMP to Cloudflare is blocked by the ISP — ping test impossible."; T_v_ping_fail_uk='❌ ICMP до Cloudflare заблоковано провайдером — пінг-тест неможливий.'
T_v_best_mark_ru=' ✅ найкращий'; T_v_best_mark_en=' ✅ best'; T_v_best_mark_uk=' ✅ найкращий'
T_v_cur_mark_ru=' (поточний)'; T_v_cur_mark_en=' (current)'; T_v_cur_mark_uk=' (поточний)'

# --- PBR: ручний список заблокованих IP ---
T_pbr_btn_ru='📋 Список'; T_pbr_btn_en='📋 List'; T_pbr_btn_uk='📋 Список'
T_pbr_btnp_ru='🟡 Тільки заблоковані'; T_pbr_btnp_en='🟡 Blocked only'; T_pbr_btnp_uk='🟡 Тільки заблоковані'
T_pbr_title_ru='📋 Список заблокованих IP (%d записів):'; T_pbr_title_en='📋 Blocked IP list (%d entries):'; T_pbr_title_uk='📋 Список заблокованих IP (%d записів):'
T_pbr_empty_ru='📋 Список порожній. Натисніть ➕ Додати.'; T_pbr_empty_en='📋 List empty. Press ➕ Add.'; T_pbr_empty_uk='📋 Список порожній. Натисніть ➕ Додати.'
T_pbr_add_ask_ru='Введіть IP або CIDR (напр. 93.184.216.34 або 5.188.86.0/24):'; T_pbr_add_ask_en='Enter IP or CIDR (e.g. 93.184.216.34 or 5.188.86.0/24):'; T_pbr_add_ask_uk='Введіть IP або CIDR (напр. 93.184.216.34 або 5.188.86.0/24):'
T_pbr_add_ok_ru='✅ Додано: %s. Додайте ще або 🔄 Застосуйте правила.'; T_pbr_add_ok_en='✅ Added: %s. Add more or 🔄 Apply rules.'; T_pbr_add_ok_uk='✅ Додано: %s. Додайте ще або 🔄 Застосуйте правила.'
T_pbr_add_bad_ru='❌ Невірний формат. Потрібно: IP або IP/N (напр. 93.184.216.34 або 5.188.86.0/24)'; T_pbr_add_bad_en='❌ Bad format. Need: IP or IP/N (e.g. 93.184.216.34 or 5.188.86.0/24)'; T_pbr_add_bad_uk='❌ Невірний формат. Потрібно: IP або IP/N (напр. 93.184.216.34 або 5.188.86.0/24)'
T_pbr_del_ok_ru='✅ Видалено: %s'; T_pbr_del_ok_en='✅ Removed: %s'; T_pbr_del_ok_uk='✅ Видалено: %s'
T_pbr_apply_ru='✅ PBR-правила застосовано. Тільки %d записів через WARP.'; T_pbr_apply_en='✅ PBR rules applied. Only %d entries via WARP.'; T_pbr_apply_uk='✅ PBR-правила застосовано. Тільки %d записів через WARP.'
T_pbr_clear_ru='✅ PBR-правила прибрано. Увесь трафік напряму.'; T_pbr_clear_en='✅ PBR rules cleared. All traffic direct.'; T_pbr_clear_uk='✅ PBR-правила прибрано. Увесь трафік напряму.'
T_pbr_no_warp_ru='⚠️ Спочатку створіть WARP (кнопка ⚡️ Підключити)'; T_pbr_no_warp_en='⚠️ Create WARP first (button ⚡️ Connect)'; T_pbr_no_warp_uk='⚠️ Спочатку створіть WARP (кнопка ⚡️ Підключити)'
T_pbr_empty_err_ru='⚠️ Список порожній — додайте хоча б один запис'; T_pbr_empty_err_en='⚠️ List empty — add at least one entry'; T_pbr_empty_err_uk='⚠️ Список порожній — додайте хоча б один запис'

# --- Speedtest ---
T_btn_spd_ru='⚡️ Швидкість'; T_btn_spd_en='⚡️ Speed'; T_btn_spd_uk='⚡️ Швидкість'
T_spd_title_ru='⚡️ Speedtest'; T_spd_title_en='⚡️ Speedtest'; T_spd_title_uk='⚡️ Speedtest'
T_spd_ask_ru='Оберіть тест:'; T_spd_ask_en='Choose test:'; T_spd_ask_uk='Оберіть тест:'
T_spd_direct_ru='🌐 Напряму'; T_spd_direct_en='🌐 Direct'; T_spd_direct_uk='🌐 Напряму'
T_spd_warp_ru='📡 Через WARP'; T_spd_warp_en='📡 Via WARP'; T_spd_warp_uk='📡 Через WARP'
T_spd_both_ru='📊 Обидва тести'; T_spd_both_en='📊 Both tests'; T_spd_both_uk='📊 Обидва тести'
T_spd_running_ru='⏳ Тестую %s…'; T_spd_running_en='⏳ Testing %s…'; T_spd_running_uk='⏳ Тестую %s…'
T_spd_fail_ru='❌ Помилка завантаження. Перевірте зʼєднання.'; T_spd_fail_en='❌ Download error. Check connection.'; T_spd_fail_uk='❌ Помилка завантаження. Перевірте зʼєднання.'
T_spd_compare_ru='⚡️ Порівняння швидкості'; T_spd_compare_en='⚡️ Speed comparison'; T_spd_compare_uk='⚡️ Порівняння швидкості'

# send_rich визначено нижче (файловий payload)

mk_markups() {
MENU_MARKUP="{\"inline_keyboard\":[[{\"text\":\"$(t btn_status)\",\"callback_data\":\"st\"},{\"text\":\"$(t btn_dev)\",\"callback_data\":\"dv\"}],[{\"text\":\"$(t btn_wifi)\",\"callback_data\":\"mnu:wifi\"},{\"text\":\"$(t btn_fw)\",\"callback_data\":\"mnu:fw\"}],[{\"text\":\"$(t btn_dg)\",\"callback_data\":\"mnu:dg\"},{\"text\":\"$(t btn_sys)\",\"callback_data\":\"mnu:sys\"}],[{\"text\":\"$(t btn_vpn)\",\"callback_data\":\"mnu:vpn\"},{\"text\":\"$(t btn_watch)\",\"callback_data\":\"wch\"}],[{\"text\":\"$(t btn_alias)\",\"callback_data\":\"al\"},{\"text\":\"$(t btn_ai)\",\"callback_data\":\"aion\"}],[{\"text\":\"$(t btn_spd)\",\"callback_data\":\"speed\"},{\"text\":\"$(t btn_help)\",\"callback_data\":\"hlp\"}]]}"
CONFIRM_MARKUP="{\"inline_keyboard\":[[{\"text\":\"$(t rbyes)\",\"callback_data\":\"rbyes\"},{\"text\":\"$(t rbno)\",\"callback_data\":\"rbno\"}]]}"
AI_CONF_MARKUP="{\"inline_keyboard\":[[{\"text\":\"$(t aic1)\",\"callback_data\":\"aic1\"},{\"text\":\"$(t aic0)\",\"callback_data\":\"aic0\"}]]}"
AI_CONF2_MARKUP="{\"inline_keyboard\":[[{\"text\":\"$(t aic1)\",\"callback_data\":\"aic1\"},{\"text\":\"$(t aic2)\",\"callback_data\":\"aic2\"}],[{\"text\":\"$(t aic0)\",\"callback_data\":\"aic0\"}]]}"
AI_MARKUP="{\"inline_keyboard\":[[{\"text\":\"$(t aioff)\",\"callback_data\":\"aioff\"}]]}"
WIFI_MARKUP="{\"inline_keyboard\":[[{\"text\":\"$(t wf_b_nets)\",\"callback_data\":\"wfkb\"},{\"text\":\"$(t btn_qr)\",\"callback_data\":\"qr\"}],[{\"text\":\"$(t btn_scan)\",\"callback_data\":\"scn\"},{\"text\":\"$(t mnback)\",\"callback_data\":\"mn\"}]]}"
FW_MARKUP="{\"inline_keyboard\":[[{\"text\":\"$(t fw_btn_pf)\",\"callback_data\":\"fwlist\"},{\"text\":\"$(t fw_addbtn)\",\"callback_data\":\"fwa\"}],[{\"text\":\"$(t mnback)\",\"callback_data\":\"mn\"}]]}"
DG_MARKUP="{\"inline_keyboard\":[[{\"text\":\"$(t dg_btn_ping)\",\"callback_data\":\"dgt:ping\"},{\"text\":\"$(t dg_btn_trace)\",\"callback_data\":\"dgt:trace\"},{\"text\":\"$(t dg_btn_ns)\",\"callback_data\":\"dgt:ns\"}],[{\"text\":\"$(t dg_btn_lr)\",\"callback_data\":\"dgl:logread\"},{\"text\":\"$(t dg_btn_dm)\",\"callback_data\":\"dgl:dmesg\"}],[{\"text\":\"$(t mnback)\",\"callback_data\":\"mn\"}]]}"
SYS_MARKUP="{\"inline_keyboard\":[[{\"text\":\"$(t btn_wan)\",\"callback_data\":\"wan\"},{\"text\":\"$(t btn_bk)\",\"callback_data\":\"bk\"}],[{\"text\":\"$(t btn_rb)\",\"callback_data\":\"rb1\"},{\"text\":\"↩️ Rollback\",\"callback_data\":\"rbk1\"}],[{\"text\":\"$(t s_btn_pkg)\",\"callback_data\":\"pkgl\"},{\"text\":\"$(t s_btn_ssh)\",\"callback_data\":\"sshkl\"}],[{\"text\":\"$(t mnback)\",\"callback_data\":\"mn\"}]]}"
RBK_CONF_MARKUP="{\"inline_keyboard\":[[{\"text\":\"$(t rbky)\",\"callback_data\":\"rbkyes\"},{\"text\":\"$(t rbno)\",\"callback_data\":\"rbkno\"}]]}"
VPN_MARKUP="{\"inline_keyboard\":[[{\"text\":\"$(t v_status)\",\"callback_data\":\"wst\"},{\"text\":\"$(t v_connect)\",\"callback_data\":\"wup1\"}],[{\"text\":\"$(t v_aon)\",\"callback_data\":\"won\"},{\"text\":\"$(t v_aoff)\",\"callback_data\":\"woff\"}],[{\"text\":\"$(t pbr_btn)\",\"callback_data\":\"pbr_menu\"},{\"text\":\"$(t v_btn_mtu)\",\"callback_data\":\"wmtu\"},{\"text\":\"$(t v_btn_ep)\",\"callback_data\":\"wep\"}],[{\"text\":\"$(t v_delete)\",\"callback_data\":\"wdel1\"}],[{\"text\":\"$(t mnback)\",\"callback_data\":\"mn\"}]]}"
WARP_CONF_MARKUP="{\"inline_keyboard\":[[{\"text\":\"$(t v_go)\",\"callback_data\":\"wgo\"},{\"text\":\"$(t rbno)\",\"callback_data\":\"aic0\"}]]}"
WDEL_CONF_MARKUP="{\"inline_keyboard\":[[{\"text\":\"🗑 $(t v_delete)\",\"callback_data\":\"wdel2\"},{\"text\":\"$(t rbno)\",\"callback_data\":\"aic0\"}]]}"
PBR_MARKUP="{\"inline_keyboard\":[[{\"text\":\"📄 $(t pbr_btn)\",\"callback_data\":\"pbr_list\"},{\"text\":\"➕ Додати\", \"callback_data\":\"pbr_add_ask\"}],[{\"text\":\"🗑 Видалити запис\",\"callback_data\":\"pbr_del\"},{\"text\":\"🔄 Застосувати\",\"callback_data\":\"pbr_apply\"}],[{\"text\":\"$(t mnback)\",\"callback_data\":\"mnu:vpn\"}]]}"
SPD_MARKUP="{\"inline_keyboard\":[[{\"text\":\"$(t spd_direct)\",\"callback_data\":\"spd:d\"},{\"text\":\"$(t spd_warp)\",\"callback_data\":\"spd:w\"}],[{\"text\":\"$(t spd_both)\",\"callback_data\":\"spd:both\"}],[{\"text\":\"$(t mnback)\",\"callback_data\":\"mn\"}]]}"
}

# --- контекст вводу текстом (.mact): mact_set <дія> | mact_get -> "дія|ввід" ---
mact_set() { printf '%s\n%s\n' "$1" "$(date +%s)" > "$DIR/.mact"; }
mact_get() {
  # повертає 0 і друкує "дія|текст", якщо контекст свіжий (<5 хв); інакше чистить і return 1
  [ -f "$DIR/.mact" ] || return 1
  MA_ACTION=$(head -n 1 "$DIR/.mact" 2>/dev/null)
  MA_TS=$(sed -n '2p' "$DIR/.mact" 2>/dev/null)
  case "$MA_TS" in ''|*[!0-9]*) rm -f "$DIR/.mact"; return 1 ;; esac
  if [ $(( $(date +%s) - MA_TS )) -gt 300 ]; then
    rm -f "$DIR/.mact"; return 1
  fi
  printf '%s|%s' "$MA_ACTION" "$1"
}

mkdir -p "$DIR"

esc() {
  printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'
}

alog() {
  # $1=тег (Q/STEP/RUN/OUT/PEND/CONF/ERR/FINAL) $2=текст; ротація при >128КБ
  CLEAN=$(printf '%s' "$2" | LC_ALL=C tr '\000-\010\013\014\016-\037\177' '************************' | tr '\n\t\r' '   ')
  printf '%s [%s] %s\n' "$(date '+%d.%m %H:%M:%S')" "$1" "$CLEAN" >> "$DIR/ailog" 2>/dev/null
  ASZ=$(wc -c < "$DIR/ailog" 2>/dev/null)
  [ "${ASZ:-0}" -gt 131072 ] && { tail -n 800 "$DIR/ailog" > "$DIR/.al" && mv "$DIR/.al" "$DIR/ailog"; }
}

html_prep() {
  # Экранирует всё и возвращает белый список тегов Telegram Bot API (HTML parse mode):
  # b/strong i/em u/ins s/strike/del code pre blockquote[ expandable] tg-spoiler a[href]
  printf '%s' "$1" \
    | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' \
    | sed 's/&lt;span class="tg-spoiler"&gt;/<span class="tg-spoiler">/g' \
    | sed 's/&lt;\/span&gt;/<\/span>/g' \
    | sed 's/&lt;strong&gt;/<b>/g' \
    | sed 's/&lt;\/strong&gt;/<\/b>/g' \
    | sed 's/&lt;em&gt;/<i>/g' \
    | sed 's/&lt;\/em&gt;/<\/i>/g' \
    | sed 's/&lt;ins&gt;/<u>/g' \
    | sed 's/&lt;\/ins&gt;/<\/u>/g' \
    | sed 's/&lt;strike&gt;/<s>/g' \
    | sed 's/&lt;del&gt;/<s>/g' \
    | sed 's/&lt;\/strike&gt;/<\/s>/g' \
    | sed 's/&lt;\/del&gt;/<\/s>/g' \
    | sed 's/&lt;b&gt;/<b>/g; s/&lt;\/b&gt;/<\/b>/g' \
    | sed 's/&lt;i&gt;/<i>/g; s/&lt;\/i&gt;/<\/i>/g' \
    | sed 's/&lt;u&gt;/<u>/g; s/&lt;\/u&gt;/<\/u>/g' \
    | sed 's/&lt;s&gt;/<s>/g; s/&lt;\/s&gt;/<\/s>/g' \
    | sed 's/&lt;code&gt;/<code>/g; s/&lt;\/code&gt;/<\/code>/g' \
    | sed 's/&lt;pre&gt;/<pre>/g; s/&lt;\/pre&gt;/<\/pre>/g' \
    | sed 's/&lt;blockquote expandable&gt;/<blockquote expandable>/g' \
    | sed 's/&lt;blockquote&gt;/<blockquote>/g' \
    | sed 's/&lt;\/blockquote&gt;/<\/blockquote>/g' \
    | sed 's/&lt;tg-spoiler&gt;/<tg-spoiler>/g' \
    | sed 's/&lt;\/tg-spoiler&gt;/<\/tg-spoiler>/g' \
    | sed -E 's|&lt;a href="(https?://[^"]*)"&gt;|<a href="\1">|g' \
    | sed -E 's|&lt;a href="(tg://user\?id=[0-9]+)"&gt;|<a href="\1">|g' \
    | sed 's|&lt;/a&gt;|</a>|g'
}

balance_tags() {
  # Автозакрытие несбалансированных тегов белого списка; лишние закрывающие выбрасываются
  printf '%s' "$1" | awk 'BEGIN{RS="\001"} {
    s=$0; out=""; d=0
    while (match(s, /<[^<>]+>/)) {
      pre=substr(s,1,RSTART-1)
      raw=substr(s,RSTART,RLENGTH)
      s=substr(s,RSTART+RLENGTH)
      out=out pre
      t=tolower(raw); nm=t; cl=0
      if (nm ~ /^<\//) { cl=1; sub(/^<\//,"",nm) } else { sub(/^</,"",nm) }
      sub(/>[[:space:]]*$/,"",nm)
      if (nm=="blockquote expandable") nm="blockquote"
      else if (nm=="strong") nm="b"
      else if (nm=="em") nm="i"
      else if (nm=="ins") nm="u"
      else if (nm=="strike") nm="s"
      else if (nm=="del") nm="s"
      else if (nm=="span class=\"tg-spoiler\"") nm="tg-spoiler"
      sub(/[[:space:]].*$/,"",nm)
      ok=(nm=="b"||nm=="i"||nm=="u"||nm=="s"||nm=="code"||nm=="pre"||nm=="blockquote"||nm=="a"||nm=="tg-spoiler")
      if (ok && cl) { if (d>0 && st[d]==nm) { d--; out=out raw } }
      else if (ok && !cl) { d++; st[d]=nm; out=out raw }
      else if (!cl || !ok) { if (!ok) out=out raw }
      else { out=out raw }
    }
    out=out s
    for (i=d; i>=1; i--) out=out "</" st[i] ">"
    printf "%s", out
  }'
}

_req() {
  # $1=метод $2=файл с JSON-телом -> ответ на stdout
  curl -s --max-time 15 "$API/$1" -H "Content-Type: application/json" --data-binary "@$2"
}

utf8fix() {
  # Прибирає контрольні символи і НЕПОВНІ UTF-8 послідовності (після байтових зрізів).
  # Валідний текст (у т.ч. кирилиця/емодзі) проходить без змін.
  printf '%s' "$1" | LC_ALL=C awk 'BEGIN{
    L=""
    for(i=1;i<=255;i++) L=L sprintf("%c",i)
  }
  {
    o=$0; out=""; n=length(o)
    for(i=1;i<=n;i++){
      b=substr(o,i,1)
      v=index(L,b)
      if(v==0){ next }                     # NUL
      if(v<32 && v!=10){ continue }        # контрольні, крім \n
      if(v==127){ continue }
      if(v>=128 && v<=191){ continue }     # сирітський continuation-байт
      if(v>=240){ need=3 }
      else if(v>=224){ need=2 }
      else if(v>=194){ need=1 }
      else { out=out b; continue }         # ASCII
      if(n-i<need){ break }                # обірваний хвіст
      ok=1
      for(j=1;j<=need;j++){
        cv=index(L,substr(o,i+j,1))
        if(cv<128||cv>191){ ok=0; break }
      }
      if(!ok){ i+=need; continue }         # битий лідер — пропустити
      out=out substr(o,i,need+1)
      i+=need
    }
    print out
  }'
}

send_rich() {
  # $1 = Rich HTML через sendRichMessage (таблиці, h1-h6, списки, details)
  # ЛІМІТ: rich_message вміщує ~30000 символів (не 4096 як звичайний sendMessage!)
  printf '{"chat_id":"%s","rich_message":{"html":"%s"}}' "$CHAT" "$(jesc "$(utf8fix "$1")")" > "$DIR/.rq"
  R=$(_req sendRichMessage "$DIR/.rq")
  echo "$R" | grep -q '"ok":true' && return 0
  echo "$R" | head -c 200 > "$DIR/lasterr"
  return 1
}

send_long() {
  # $1=готовый HTML $2=markup(опц.); шлёт частинами <=3800 байт по границам строк (лимит TG 4096)
  RC=0; TXT="$(utf8fix "$1")"; MK="${2:-}"
  while [ -n "$TXT" ]; do
    if [ ${#TXT} -le 3800 ]; then CUR="$TXT"; TXT=""
    else
      HEAD=$(printf '%s' "$TXT" | head -c 3800)
      OFF=$(printf '%s' "$HEAD" | grep -abo '^' 2>/dev/null | tail -n 1 | cut -d: -f1)
      case "${OFF:-}" in ''|0) OFF=3795 ;; esac
      CUR=$(printf '%s' "$TXT" | head -c "$OFF")
      TXT=$(printf '%s' "$TXT" | tail -c +"$((OFF+1))")
    fi
    printf '{"chat_id":"%s","parse_mode":"HTML","text":"%s"%s}' \
      "$CHAT" "$(jesc "$CUR")" "${MK:+,\"reply_markup\":$MK}" > "$DIR/.rq"
    R=$(_req sendMessage "$DIR/.rq")
    echo "$R" | grep -q '"ok":true' || RC=1
  done
  return $RC
}

reply_rich() {
  # $1 = текст модели с rich-тегами -> спершу Rich, потім sendMessage, потім plain
  E=$(balance_tags "$(html_prep "$1")")
  [ -z "$(printf '%s' "$E" | tr -d '[:space:]')" ] && return 0
  send_rich "$E" && return 0
  send_long "$E" && return 0
  P=$(printf '%s' "$1" | sed 's/<[^>]*>//g')
  send_long "$(esc "$P")" || printf '%s' "$1" > "$DIR/lasterr"
}

reply() {
  # $1 = готовий HTML — БЕЗ повторного екранування (теги навмисні)
  send_long "$1" || printf '%s' "$1" > "$DIR/lasterr"
}

reply_doc() {
  # $1=file $2=caption
  curl -s --max-time 90 "$API/sendDocument" \
    -F "chat_id=$CHAT" -F "parse_mode=HTML" \
    -F "document=@$1" --form-string "caption=$2" > "$DIR/lastdoc" 2>/dev/null
  grep -q '"ok":true' "$DIR/lastdoc" || mv "$DIR/lastdoc" "$DIR/lasterr"
  rm -f "$DIR/lastdoc"
}

reply_photo_url() {
  printf '{"chat_id":"%s","photo":"%s","parse_mode":"HTML","caption":"%s"}' \
    "$CHAT" "$1" "$(jesc "$2")" > "$DIR/.rq"
  _req sendPhoto "$DIR/.rq" | grep -q '"ok":true' || echo "sendPhoto fail: $1" > "$DIR/lasterr"
}

reply_photo_file() {
  curl -s --max-time 30 "$API/sendPhoto" \
    -F "chat_id=$CHAT" -F "photo=@$1" --form-string "caption=$2" \
    | grep -q '"ok":true' || echo "sendPhoto(file) fail" > "$DIR/lasterr"
  rm -f "$1"
}

send_menu() {
  printf '{"chat_id":"%s","parse_mode":"HTML","text":"%s","reply_markup":%s}' \
    "$CHAT" "$(jesc "${1:-🤖}")" "$MENU_MARKUP" > "$DIR/.rq"
  _req sendMessage "$DIR/.rq" >/dev/null
}

send_mk() {
  # $1=текст $2=reply_markup JSON
  printf '{"chat_id":"%s","parse_mode":"HTML","text":"%s"%s}' \
    "$CHAT" "$(jesc "$1")" "${2:+,\"reply_markup\":$2}" > "$DIR/.rq"
  _req sendMessage "$DIR/.rq" >/dev/null
}

send_mk_getid() {
  # $1=текст $2=reply_markup JSON -> message_id на stdout
  printf '{"chat_id":"%s","parse_mode":"HTML","text":"%s"%s}' \
    "$CHAT" "$(jesc "$1")" "${2:+,\"reply_markup\":$2}" > "$DIR/.rq"
  RESP=$(_req sendMessage "$DIR/.rq")
  printf '%s' "$RESP" | grep -o '"message_id":[0-9]*' | head -1 | cut -d: -f2
}

edit_msg() {
  ET=$(printf '%s' "$2" | head -c 4000)
  printf '{"chat_id":"%s","message_id":%s,"parse_mode":"HTML","text":"%s"%s}' \
    "$CHAT" "$1" "$(jesc "$ET")" "${3:+,\"reply_markup\":$3}" > "$DIR/.rq"
  _req editMessageText "$DIR/.rq" >/dev/null
}

edit_msg_rich() {
  # $1=message_id $2=Rich HTML — редагування rich-повідомлення
  printf '{"chat_id":"%s","message_id":%s,"rich_message":{"html":"%s"}}' \
    "$CHAT" "$1" "$(jesc "$2")" > "$DIR/.rq"
  _req editMessageText "$DIR/.rq" >/dev/null
}

answer_cb() {
  curl -s --max-time 10 "$API/answerCallbackQuery" \
    -d "callback_query_id=$1" >/dev/null
}

typing() {
  # $1=typing|upload_document|upload_photo (индикатор в чате)
  curl -s --max-time 10 "$API/sendChatAction" \
    -d "chat_id=$CHAT" -d "action=${1:-typing}" >/dev/null
}

register_commands() {
  # Список команд для кнопки ☰ Menu в Telegram
  CMDS="{\"commands\":[{\"command\":\"status\",\"description\":\"$(t c_status)\"},{\"command\":\"devices\",\"description\":\"$(t c_dev)\"},{\"command\":\"wan\",\"description\":\"$(t c_wan)\"},{\"command\":\"backup\",\"description\":\"$(t c_bk)\"},{\"command\":\"qr\",\"description\":\"$(t c_qr)\"},{\"command\":\"scan\",\"description\":\"$(t c_scan)\"},{\"command\":\"ai\",\"description\":\"$(t c_ai)\"},{\"command\":\"alias\",\"description\":\"$(t c_alias)\"},{\"command\":\"watch\",\"description\":\"$(t c_watch)\"},{\"command\":\"mon\",\"description\":\"$(t c_mon)\"},{\"command\":\"reboot\",\"description\":\"$(t c_rb)\"},{\"command\":\"ailog\",\"description\":\"$(t c_ailog)\"},{\"command\":\"model\",\"description\":\"$(t c_mdl)\"},{\"command\":\"key\",\"description\":\"$(t c_key)\"},{\"command\":\"topo\",\"description\":\"$(t c_topo)\"},{\"command\":\"rollback\",\"description\":\"$(t c_rback)\"},{\"command\":\"wifi\",\"description\":\"$(t c_wifi)\"},{\"command\":\"usage\",\"description\":\"$(t c_usage)\"},{\"command\":\"cancel\",\"description\":\"$(t c_cancel)\"},{\"command\":\"help\",\"description\":\"$(t c_help)\"}]}"
  curl -s --max-time 15 "$API/setMyCommands" \
    -H "Content-Type: application/json" \
    -d "$CMDS" | grep -q '"ok":true' || {
    sleep 5
    curl -s --max-time 15 "$API/setMyCommands" \
      -H "Content-Type: application/json" \
      -d "$CMDS" | grep -q '"ok":true' \
      || echo "setMyCommands fail" > "$DIR/lasterr"
  }
}

pulse_send() {
  printf '{"chat_id":"%s","rich_message":{"html":"%s"}}' "$CHAT" "$(jesc "$1")" > "$DIR/.rq"
  _req sendRichMessage "$DIR/.rq" | grep -o '"message_id":[0-9]*' | grep -o '[0-9]*' > "$DIR/msgid"
}

pulse_edit_or_send() {
  MSGID=""
  [ -f "$DIR/msgid" ] && MSGID=$(cat "$DIR/msgid")
  if [ -n "$MSGID" ]; then
    edit_msg_rich "$MSGID" "$1"
    return
  fi
  pulse_send "$1"
}

uptime_short() {
  U=$(uptime | sed 's/.*up //; s/, *[0-9]* users*//; s/, *load average.*//')
  case "$U" in
    *" min"*|*" min,"*)
      MIN=$(printf '%s' "$U" | cut -d' ' -f1)
      printf "$(t u_min)" "$MIN"
      ;;
    *day*)
      D=$(printf '%s' "$U" | cut -d' ' -f1)
      HM=$(printf '%s' "$U" | awk -F', ' '{print $2}')
      H=${HM%%:*}
      M=${HM##*:}
      printf "$(t u_day)" "$D" "$H" "$M"
      ;;
    *:*)
      H=${U%%:*}
      M=${U##*:}
      printf "$(t u_hm)" "$H" "$M"
      ;;
    *)
      printf '%s' "$U"
      ;;
  esac
}

alias_help() {
  t al_help
}

watch_menu_ui() {
  T=/tmp/tg-w.$$
  awk '{print $3"|"$4"|"$2}' /tmp/dhcp.leases 2>/dev/null | sort -t'|' -k1,1 -u > "$T"
  ROWS=""
  ROW=""
  CNT=0
  while IFS='|' read -r IP NM MAC; do
    A=$(alias_of "$IP")
    [ -n "$A" ] && NM="$A"
    [ "$NM" = "*" ] && NM=""
    [ -z "$NM" ] && NM="$(t d_name)-${IP##*.}"
    E=$(esc "$NM" | sed 's/"/\\"/g')
    INW=$(grep -ci "^${MAC}|" "$DIR/presence.cfg" 2>/dev/null)
    if [ "${INW:-0}" != "0" ]; then
      BTN="{\"text\":\"✅ $E\",\"callback_data\":\"wdel:$MAC\"}"
    else
      BTN="{\"text\":\"$E\",\"callback_data\":\"wadd:$MAC\"}"
    fi
    if [ $((CNT % 2)) -eq 0 ]; then
      [ -n "$ROW" ] && { ROWS="$ROWS[$ROW],"; ROW=""; }
      ROW="$BTN"
    else
      ROW="$ROW,$BTN"
    fi
    CNT=$((CNT+1))
  done < "$T"
  rm -f "$T"
  [ -n "$ROW" ] && ROWS="$ROWS[$ROW],"
  ROWS="${ROWS}[{\"text\":\"$(t mnback)\",\"callback_data\":\"mn\"}]"
  WTXT="$(t w_intro)"
  [ "$CNT" = "0" ] && WTXT="$(t w_intro)

$(t w_empty)"
  WMK="{\"inline_keyboard\":[$ROWS]}"
}

internet_ok() {
  ping -c1 -W2 8.8.8.8 >/dev/null 2>&1 && t net_yes || t net_no
}

status_text() {
  MEM=$(free | awk '/Mem:/ {printf "%d/%d MB", $3/1024, $2/1024}')
  WANIP=$(ip addr show wan 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1)
  PUBIP=$(curl -s --max-time 5 https://api.ipify.org)
  NET=$(internet_ok)
  R="<h3>$(t s_hdr)</h3><table bordered striped>"
  R="$R<tr><td>$(t s_up)</td><td><code>$(uptime_short)</code></td></tr>"
  R="$R<tr><td>$(t s_load)</td><td><code>$(cut -d' ' -f1-3 /proc/loadavg)</code></td></tr>"
  R="$R<tr><td>$(t s_ram)</td><td><code>$MEM</code></td></tr>"
  [ -n "$WANIP" ] && R="$R<tr><td>$(t s_wan)</td><td><code>$WANIP</code></td></tr>"
  [ -n "$PUBIP" ] && R="$R<tr><td>$(t s_pub)</td><td><code>$PUBIP</code></td></tr>"
  R="$R<tr><td>$(t s_net)</td><td>$NET</td></tr>"
  R="$R</table><footer>🕐 $(date '+%d.%m.%Y %H:%M:%S')</footer>"
  printf '%s' "$R"
}

alias_of() {
  # $1=IP -> имя из /etc/tg-bot/aliases или пусто
  [ -f "$DIR/aliases" ] && grep -m1 "^$1|" "$DIR/aliases" | cut -d'|' -f2
}

devices_text() {
  T=/tmp/tg-devs.$$
  AT=/tmp/tg-arp.$$
  awk '$3=="0x2" && $1 ~ /^192\.168\./ {print $1}' /proc/net/arp > "$AT"

  if [ ! -s /tmp/dhcp.leases ]; then
    t d_none
    rm -f "$AT"
    return
  fi

  awk '{print $3"|"$4"|"$2}' /tmp/dhcp.leases \
    | sort -t'|' -k1,1 -u > "$T"

  ONLINE=0
  TOTAL=0
  ON=""
  OFF=""
  while IFS='|' read -r IP NAME MAC; do
    TOTAL=$((TOTAL+1))
    A=$(alias_of "$IP")
    [ -n "$A" ] && NAME="$A"
    [ "$NAME" = "*" ] && NAME=""
    [ -z "$NAME" ] && NAME="$(t d_name)-${IP##*.}"
    [ ${#NAME} -gt 30 ] && NAME=$(printf '%s' "$NAME" | head -c 30)
    NAME=$(esc "$NAME")
    if grep -qxF "$IP" "$AT"; then
      ONLINE=$((ONLINE+1))
      ON="$ON<tr><td>$IP</td><td align=\"center\">🟢</td><td><b>$NAME</b></td></tr>"
    else
      OFF="$OFF<tr><td>$IP</td><td align=\"center\">⚪️</td><td>$NAME</td></tr>"
    fi
  done < "$T"

  printf "$(t d_hdr2)" "$ONLINE" "$TOTAL"
  TH="<tr><th>IP</th><th>$(t th_state)</th><th>$(t th_name)</th></tr>"
  [ -n "$ON" ] && printf '<table bordered striped>%s%s</table>' "$TH" "$ON"
  [ -n "$OFF" ] && { printf "$(t d_offttl)" "$((TOTAL-ONLINE))"; printf '<table bordered striped>%s%s</table>' "$TH" "$OFF"; }
  rm -f "$T" "$AT"
}

help_text() {
  t help
}

menu_text() {
  printf "$(t m_title)" "$(uptime_short)" "$(internet_ok)"
}

# --- новые команды ---

cmd_backup() {
  TS=$(date '+%Y%m%d-%H%M')
  B="/tmp/tg-backup-$TS.tar.gz"
  typing
  reply "$(t b_gather)"
  (cd / && tar -czf "$B" etc/config etc/tg-bot etc/crontabs/root 2>/dev/null)
  if [ -s "$B" ]; then
    reply_doc "$B" "$(t b_ok)"
  else
    reply "$(t b_fail)"
  fi
  rm -f "$B"
}

cmd_alias() {
  # /alias IP [Имя...] | /alias del IP
  OP=$(echo "$1" | awk '{print tolower($2)}')
  if [ "$OP" = "del" ]; then
    IP=$(echo "$1" | awk '{print toupper($3)}')
    [ -z "$IP" ] && { reply "$(t al_delfmt)"; return; }
    grep -v "^$IP|" "$DIR/aliases" 2>/dev/null > "$DIR/aliases.new"
    mv "$DIR/aliases.new" "$DIR/aliases"
    reply "$(printf "$(t al_del)" "$IP")"
    return
  fi
  IP=$(echo "$1" | awk '{print toupper($2)}')
  NM=$(echo "$1" | awk '{out=""; for(i=3;i<=NF;i++) out=out (i>3?" ":"") $i; print out}')
  if [ -z "$IP" ] || [ -z "$NM" ]; then
    reply "$(t al_fmt)"
    return
  fi
  echo "$1" | grep -qE "/alias +[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3} +" \
    || { reply "$(t al_badip)"; return; }
  grep -v "^$IP|" "$DIR/aliases" 2>/dev/null > "$DIR/aliases.new"
  mv "$DIR/aliases.new" "$DIR/aliases"
  echo "$IP|$NM" >> "$DIR/aliases"
  reply "$(printf "$(t al_done)" "$IP" "$(esc "$NM")")"
}

cmd_watch() {
  # /watch add MAC Имя | /watch del MAC | /watch list
  OP=$(echo "$1" | awk '{print tolower($2)}')
  CF="$DIR/presence.cfg"
  touch "$CF"
  if [ "$OP" = "list" ]; then
    N=$(grep -c . "$CF" 2>/dev/null)
    if [ "$N" = "0" ] || [ -z "$N" ]; then
      reply "$(t wl_empty)"
    else
      ROWS=""
      while IFS='|' read -r MC NM; do
        ROWS="$ROWS<tr><td><code>$MC</code></td><td>$(esc "$NM")</td></tr>"
      done < "$CF"
      MSG="<h3>$(t wl_hdr)</h3><table bordered striped><tr><th>MAC</th><th>$(t th_name)</th></tr>$ROWS</table>"
      send_rich "$MSG" || reply "$MSG"
    fi
    return
  fi
  MC=$(echo "$1" | awk '{print toupper($3)}')
  echo "$MC" | grep -qE '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' || { reply "$(t w_badmac)"; return; }
  if [ "$OP" = "del" ]; then
    grep -vi "^$MC|" "$CF" > "$CF.new"; mv "$CF.new" "$CF"
    grep -vi "^$MC|" "$DIR/presence.state" 2>/dev/null > "$DIR/presence.state.new"
    mv "$DIR/presence.state.new" "$DIR/presence.state" 2>/dev/null
    reply "$(t w_del)"
    return
  fi
  NM=$(echo "$1" | awk '{out=""; for(i=4;i<=NF;i++) out=out (i>4?" ":"") $i; print out}')
  [ -z "$NM" ] && NM="$(t g_pre)-${MC##*:}"
  grep -vi "^$MC|" "$CF" > "$CF.new"; mv "$CF.new" "$CF"
  echo "$MC|$NM" >> "$CF"
  reply "$(printf "$(t w_follow)" "$(esc "$NM")" "$MC")"
}

cmd_mon() {
  # /mon add host Метка | /mon del host | /mon list
  OP=$(echo "$1" | awk '{print tolower($2)}')
  CF="$DIR/mon.cfg"
  touch "$CF"
  if [ "$OP" = "list" ]; then
    N=$(grep -c . "$CF" 2>/dev/null)
    if [ "$N" = "0" ] || [ -z "$N" ]; then
      reply "$(t mon_empty)"
    else
      ROWS=""
      while IFS='|' read -r H LB ST; do
        [ "$ST" = "1" ] && S="🟢" || S="⚫️"
        ROWS="$ROWS<tr><td><code>$H</code></td><td align=\"center\">$S</td><td>$(esc "$LB")</td></tr>"
      done < "$CF"
      MSG="<h3>$(t mon_hdr)</h3><table bordered striped><tr><th>Host</th><th>$(t th_state)</th><th>$(t th_name)</th></tr>$ROWS</table>"
      send_rich "$MSG" || reply "$MSG"
    fi
    return
  fi
  H=$(echo "$1" | awk '{print $3}')
  [ -z "$H" ] && { reply "$(t mon_addfmt)"; return; }
  if [ "$OP" = "del" ]; then
    grep -v "^$H|" "$CF" > "$CF.new"; mv "$CF.new" "$CF"
    reply "$(t mon_del)"
    return
  fi
  LB=$(echo "$1" | awk '{out=""; for(i=4;i<=NF;i++) out=out (i>4?" ":"") $i; print out}')
  [ -z "$LB" ] && LB="$H"
  grep -v "^$H|" "$CF" > "$CF.new"; mv "$CF.new" "$CF"
  echo "$H|$LB|?" >> "$CF"
  reply "$(printf "$(t mon_fol)" "$H" "$(esc "$LB")")"
}

wifi_creds() {
  SSID=$(uci -q show wireless 2>/dev/null | sed -n "s/^wireless\.[^.]*\.ssid='\([^']*\)'.*/\1/p" | head -1)
  KEY=$(uci -q show wireless 2>/dev/null | sed -n "s/^wireless\.[^.]*\.key='\([^']*\)'.*/\1/p" | head -1)
}

cmd_qr() {
  wifi_creds
  if [ -z "$SSID" ]; then
    reply "$(t q_notfound)"
    return
  fi
  ESC_S=$(printf '%s' "$SSID" | sed 's/[\\;,:"]/\\&/g')
  ESC_K=$(printf '%s' "$KEY" | sed 's/[\\;,:"]/\\&/g')
  DATA="WIFI:T:WPA;S:$ESC_S;P:$ESC_K;;"
  QRURL="https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=$(printf '%s' "$DATA" | sed 's/:/%3A/g; s/;/%3B/g')"
  reply_photo_url "$QRURL" "$(printf "$(t q_cap)" "$(esc "$SSID")")$(t q_note)"
}

jesc() {
  # JSON-екранування: \ -> \\ , " -> \" , таб->пробіл, перенос -> \n , контрольні геть
  printf '%s' "$1" \
    | LC_ALL=C sed 's/\\/\\\\/g; s/"/\\"/g' \
    | LC_ALL=C tr -d '\000-\010\013\014\016-\037\177' \
    | LC_ALL=C tr '\011' ' ' \
    | tr '\n' '\001' \
    | sed 's/\x01/\\n/g'
}

ai_snapshot() {
  SNAP="аптайм: $(uptime_short); RAM: $(free | awk '/Mem:/ {printf "%d/%d MB", $3/1024, $2/1024}'); интернет: $(internet_ok); load: $(cut -d' ' -f1 /proc/loadavg); WAN IP: $(ip addr show wan 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1)"
  WIFACE=$(iwinfo 2>/dev/null | head -3 | awk -F'EAPOL| ' '{print $1}' | tr '\n' ',')
  SNAP="$SNAP; WiFi-интерфейсы: ${WIFACE:-нет} (скан/assoclist делай по ЭТОМУ имени, не wlan0)"
  SSIDC=$(uci -q get wireless.@wifi-iface[0].ssid 2>/dev/null); CHC=$(uci -q get wireless.radio0.channel 2>/dev/null)
  [ -n "$SSIDC" ] && SNAP="$SNAP; наш SSID: $SSIDC канал: ${CHC:-auto}"
  WANRAW=$(ip addr show wan 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1)
  LIP=$(uci -q get network.lan.ipaddr 2>/dev/null)
  [ -n "$LIP" ] && SNAP="$SNAP; LAN IP роутера: $LIP (адмінка LuCI: http://$LIP/cgi-bin/luci/)"
  case "$WANRAW" in
    100.6*|100.7*|100.8*|100.9*|100.12[0-7].*) SNAP="$SNAP; ВАЖНО: CGNAT активен — проброс портов из интернета бесполезен, всегда предупреждай об этом" ;;
  esac
  DEVS=$(devices_text | sed 's/<\/tr>/\n/g; s/<[^>]*>//g' | grep '🟢' | tr '\n' ';' | sed 's/;[[:space:]]*;/; /g' | head -c 400)
}

devices_kb() {
  # Кнопки швидкої дії для онлайн-хостів: ПО ОДНІЙ на рядок (щоб не обрізались),
  # підпис = ім'я з DHCP + останній октет IP; cb = st:MAC|IP
  AT=/tmp/kba.$$
  awk '$3=="0x2"{print $1}' /proc/net/arp > "$AT"
  KB=""; N=0
  [ -s /tmp/dhcp.leases ] || { rm -f "$AT"; return 1; }
  while read -r TS MAC IP NAME CID; do
    grep -qxF "$IP" "$AT" || continue
    N=$((N+1)); [ $N -gt 8 ] && break
    NM="$NAME"
    case "$NM" in "*"|"") NM="$(t d_name)-${IP##*.}" ;; esac
    NM=$(printf '%s' "$NM" | sed 's/"/\\"/g' | head -c 24)
    KB="$KB[{\"text\":\"⚙️ $NM · .${IP##*.}\",\"callback_data\":\"st:$MAC|$IP\"}],"
  done < /tmp/dhcp.leases
  rm -f "$AT"
  KB=${KB%,}
  [ -z "$KB" ] && return 1
  printf '{"inline_keyboard":[%s]}' "$KB"
}

st_lease_add() {
  # $1=MAC $2=IP → статична аренда + dnsmasq restart
  uci add dhcp host >/dev/null 2>&1
  uci set dhcp.@host[-1].mac="$1" >/dev/null
  uci set dhcp.@host[-1].ip="$2" >/dev/null
  uci set dhcp.@host[-1].name="static-${2##*.}" >/dev/null
  uci commit dhcp && /etc/init.d/dnsmasq restart >/dev/null 2>&1
}

# --- Wi-Fi керування (фаза 2) ---
wf_list() {
  # -> рядки "idx|ssid|disabled|channel|txpower|device" по одному на wifi-iface
  N=0
  while :; do
    S=$(uci -q get wireless.@wifi-iface[$N].ssid 2>/dev/null) || break
    D=$(uci -q get wireless.@wifi-iface[$N].device 2>/dev/null)
    DIS=$(uci -q get wireless.$D.disabled 2>/dev/null); DIS=${DIS:-0}
    CH=$(uci -q get wireless.$D.channel 2>/dev/null); CH=${CH:-auto}
    PW=$(uci -q get wireless.$D.txpower 2>/dev/null); PW=${PW:-max}
    printf '%s|%s|%s|%s|%s|%s\n' "$N" "$S" "$DIS" "$CH" "$PW" "$D"
    N=$((N+1))
  done
}

wf_kb() {
  # клавіатура вибору мережі (cb = wf:<idx>); пусто/rc1 = немає інтерфейсів
  KB=""
  TMPF="$DIR/.wfl.$$"; wf_list > "$TMPF" || { rm -f "$TMPF"; return 1; }
  while IFS='|' read -r N SS DIS CH PW D; do
    ST=📶; [ "$DIS" = "1" ] && ST=⏻
    KB="$KB[{\"text\":\"$ST $(esc "$SS") · $CH\",\"callback_data\":\"wf:$N\"}],"
  done < "$TMPF"
  rm -f "$TMPF"
  KB=${KB%,}
  [ -z "$KB" ] && return 1
  printf '{"inline_keyboard":[%s,[{"text":"%s","callback_data":"mn"}]]}' "$KB" "$(t mnback)"
}

wf_view() {
  # $1=idx -> текст стану мережі в OUTW; клавіатура дій у WF_KB; rc1 = поганий idx
  case "$1" in ''|*[!0-9]*) return 1 ;; esac
  SS=$(uci -q get wireless.@wifi-iface[$1].ssid 2>/dev/null) || return 1
  KY=$(uci -q get wireless.@wifi-iface[$1].key 2>/dev/null)
  ENC=$(uci -q get wireless.@wifi-iface[$1].encryption 2>/dev/null)
  D=$(uci -q get wireless.@wifi-iface[$1].device 2>/dev/null)
  DIS=$(uci -q get wireless.$D.disabled 2>/dev/null); DIS=${DIS:-0}
  CH=$(uci -q get wireless.$D.channel 2>/dev/null); CH=${CH:-auto}
  PW=$(uci -q get wireless.$D.txpower 2>/dev/null); PW=${PW:-max}
  ST=🟢; [ "$DIS" = "1" ] && ST=⏻
  OUTW=$(printf "$(t wf_hdr)" "$ST" "$(esc "${ENC:-?}")" "$(esc "$SS")" "$(esc "${KY:-(немає)}")" "$CH" "$PW")
  WF_KB="{\"inline_keyboard\":[[{\"text\":\"$(t wf_b_key)\",\"callback_data\":\"wfk:$1\"},{\"text\":\"$(t wf_b_ssid)\",\"callback_data\":\"wfs:$1\"}],[{\"text\":\"$(t wf_b_ch)\",\"callback_data\":\"wfc:$1\"},{\"text\":\"$(t wf_b_pwr)\",\"callback_data\":\"wfp:$1\"}],[{\"text\":\"$(t wf_b_tgl)\",\"callback_data\":\"wft:$1\"},{\"text\":\"$(t mnback)\",\"callback_data\":\"mnu:wifi\"}]]}"
}

wf_confirm() {
  # $1=команда → черга підтвердження aic1/aic2(з DMS-страховкою)/aic0
  printf '%s' "$1" > "$DIR/aipend"
  send_mk "$(printf "$(t wf_conf)" "$(esc "$1")")" "$AI_CONF2_MARKUP"
}

wf_apply() {
  # $1=uci-рядок без commit -> + autocommit + wifi reload, через підтвердження
  wf_confirm "$(uci_autocommit "$1") && wifi reload"
}

wf_safe() {
  # $1=значення від користувача (ssid/пароль) -> rc1 = містить ' або керуючі байти
  case "$1" in *"'"*) return 1 ;; esac
  printf '%s' "$1" | grep -q '[[:cntrl:]]' && return 1
  return 0
}

# --- Фаєрвол (фаза 3) ---
ok_port() {
  # $1 -> rc0 = число 1-65535
  case "$1" in ''|*[!0-9]*) return 1 ;; esac
  [ "$1" -ge 1 ] && [ "$1" -le 65535 ]
}
ok_ip() {
  printf '%s' "$1" | awk -F. 'NF==4{for(i=1;i<=4;i++)if($i!~/^[0-9]+$/||$i+0>255)exit 1;exit 0}{exit 1}'
}
fw_redirects() {
  # -> рядки "idx|name|proto|sport|dip|dport" по одному на redirect
  N=0
  while :; do
    P=$(uci -q get firewall.@redirect[$N].src_dport 2>/dev/null) || break
    NM=$(uci -q get firewall.@redirect[$N].name 2>/dev/null)
    PR=$(uci -q get firewall.@redirect[$N].proto 2>/dev/null); PR=${PR:-tcp udp}
    DI=$(uci -q get firewall.@redirect[$N].dest_ip 2>/dev/null)
    DP=$(uci -q get firewall.@redirect[$N].dest_port 2>/dev/null); DP=${DP:-$P}
    printf '%s|%s|%s|%s|%s|%s\n' "$N" "${NM:-?}" "$PR" "$P" "${DI:-?}" "$DP"
    N=$((N+1))
  done
}
fw_kb() {
  # клавіатура списку пробросів: fwdel:<idx>; пусто/rc1 = немає правил
  KB=""; TMPF="$DIR/.fwl.$$"
  fw_redirects > "$TMPF" || { rm -f "$TMPF"; return 1; }
  while IFS='|' read -r N NM PR SP DI DP; do
    KB="$KB[{\"text\":\"❌ ${SP}→${DI}:${DP} (${PR})\",\"callback_data\":\"fwdel:$N\"}],"
  done < "$TMPF"
  rm -f "$TMPF"
  KB=${KB%,}
  [ -z "$KB" ] && return 1
  printf '{"inline_keyboard":[%s]}' "$KB"
}
fw_confirm() {
  # $1=команда → черга підтвердження aic1/aic2(з DMS)/aic0
  printf '%s' "$1" > "$DIR/aipend"
  send_mk "$(printf "$(t fwd_conf)" "$(esc "$1")")" "$AI_CONF2_MARKUP"
}

# --- токен-оптимізація: хелпери (фази A/C/D/F/G) ---
trim_out() {
  # $1=текст [$2=ліміт, дефолт 1000] -> head+tail з маркером обрізання (економія токенів фідбеку)
  TX="$1"; L="${2:-1000}"
  [ "${#TX}" -le "$L" ] && { printf '%s' "$TX"; return; }
  H=$((L*6/10)); T=$((L*4/10))
  printf '%s\n…(обрізано, повний вивід у журналі бота)…\n%s' \
    "$(printf '%s' "$TX" | head -c $H)" "$(printf '%s' "$TX" | tail -c $T)"
}
semi_split() {
  # $1=рядок -> розріз по ; ПОЗА лапками ('…' і "…" — літерали); частини з нового рядка.
  # Модель досі шле старі ";-ланцюжки" замість CMD2: — розрізаємо механічно у батч читання.
  printf '%s\n' "$1" | awk '{
    s=$0; out=""; q=0; dq=0
    for (j=1; j<=length(s); j++) {
      c=substr(s,j,1)
      if (c=="\047" && dq==0) q=!q
      else if (c=="\"" && q==0) dq=!dq
      if (c==";" && q==0 && dq==0) { print out; out="" }
      else out=out c
    }
    print out
  }'
}
tok_log() {
  # $1=model $2=prompt_tokens $3=completion_tokens -> рядок у toklog (ротація 20КБ)
  [ -n "$2" ] || return 0
  printf '%s|%s|%s|%s\n' "$(date +%s)" "$1" "${2:-0}" "${3:-0}" >> "$DIR/toklog" 2>/dev/null
  tail -c 20000 "$DIR/toklog" > "$DIR/toklog.t" 2>/dev/null && mv "$DIR/toklog.t" "$DIR/toklog"
}
prog_msg() {
  # $1=HTML -> створює або редагує ЄДНЕ повідомлення прогресу (msgid у $DIR/.pmid)
  PM=$(cat "$DIR/.pmid" 2>/dev/null)
  if [ -n "$PM" ]; then
    printf '{"chat_id":"%s","message_id":%s,"parse_mode":"HTML","text":"%s"}' \
      "$CHAT" "$PM" "$(jesc "$1")" > "$DIR/.rq"
    _req editMessageText "$DIR/.rq" >/dev/null || rm -f "$DIR/.pmid"
  else
    RSP=$(printf '{"chat_id":"%s","parse_mode":"HTML","text":"%s"}' \
      "$CHAT" "$(jesc "$1")" > "$DIR/.rq"; _req sendMessage "$DIR/.rq")
    NM=$(printf '%s' "$RSP" | jsonfilter -e '$.result.message_id' 2>/dev/null)
    [ -n "$NM" ] && echo "$NM" > "$DIR/.pmid"
  fi
}
prog_done() { rm -f "$DIR/.pmid"; }

state_rebuild() {
  # Повний механічний знімок статичних параметрів -> $DIR/ai/state.md (0 токенів).
  # Викликається: на старті якщо нема/застарів, після кожної мутації, раз на добу з пульса.
  SB=$(cat /tmp/sysinfo/model 2>/dev/null)
  FW=$(grep DISTRIB_RELEASE /etc/openwrt_release 2>/dev/null | cut -d"'" -f2)
  LANIP=$(uci -q get network.lan.ipaddr 2>/dev/null)
  WANIP=$(ip addr show wan 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1)
  CGN=""
  case "$WANIP" in 100.6[4-9].*|100.7*|100.8*|100.9*|100.1[01][0-9].*|100.12[0-7].*) CGN=" (CGNAT — проброс ззовні не працює)" ;; esac
  DNSU=$(uci -q get dhcp.@dnsmasq[0].server 2>/dev/null | tr ' ' ',' | sed "s/'//g"); DNSU=${DNSU:-авто від провайдера}
  WF=""
  N=0
  while :; do
    S=$(uci -q get wireless.@wifi-iface[$N].ssid 2>/dev/null) || break
    D=$(uci -q get wireless.@wifi-iface[$N].device 2>/dev/null)
    EN=$(uci -q get wireless.$D.disabled 2>/dev/null); EN=${EN:-0}
    ST=on; [ "$EN" = "1" ] && ST=off
    CH=$(uci -q get wireless.$D.channel 2>/dev/null); CH=${CH:-auto}
    PW=$(uci -q get wireless.$D.txpower 2>/dev/null); PW=${PW:-max}
    KY=$(uci -q get wireless.@wifi-iface[$N].key 2>/dev/null); KY=${KY:+(пароль відомий боту)}
    WF="$WF
- SSID \"$S\": радіо $ST, канал $CH, потужність $PW, ${KY:-без пароля}"
    N=$((N+1))
  done
  PFC=0; while :; do uci -q get firewall.@redirect[$PFC].src_dport >/dev/null 2>&1 || break; PFC=$((PFC+1)); done
  PKG=""
  for P in nlbwmon sqm-scripts wireguard-tools adblock https-dns-proxy miniupnpd luci-proto-wireguard; do
    apk info -e "$P" >/dev/null 2>&1 && PKG="$PKG $P"
  done
  mkdir -p "$DIR/ai" 2>/dev/null
  {
    printf '# СТАН РОУТЕРА (оновлено %s)\n' "$(date '+%d.%m %H:%M')"
    printf 'Модель: %s | Прошивка: ImmortalWrt %s\n' "${SB:-?}" "${FW:-?}"
    printf 'LAN IP: %s | WAN IP: %s%s\n' "${LANIP:-?}" "${WANIP:-невідомо}" "${CGN}"
    printf 'DNS upstream (dnsmasq): %s\n' "$DNSU"
    [ -n "$WF" ] && printf 'Wi-Fi:%s\n' "$WF"
    printf 'Портфорвордів WAN: %s\n' "$PFC"
    printf 'Додаткові пакети:%s\n' "${PKG:- немає}"
    if uci -q get network.warp >/dev/null 2>&1; then
      RA=$(uci -q get network.@wireguard_warp[0].route_allowed_ips 2>/dev/null)
      WP=$(uci -q get network.@wireguard_warp[0].endpoint_port 2>/dev/null); WP=${WP:-2408}
      WS="тунель створений, трафік НЕ перехоплюється"
      [ "${RA:-0}" = "1" ] && WS="АКТИВНИЙ — ВЕСЬ трафік роутера йде через WARP"
      printf 'VPN: Cloudflare WARP (порт %s) — %s\n' "$WP" "$WS"
    else
      printf 'VPN: WARP не налаштований (є кнопковий розділ 🌐 VPN).\n'
    fi
    printf '\nЦЕ КЕШ: параметри вважай чинними без перевірки CMD; оновлюється ботом автоматично після кожної зміни.\n'
  } > "$DIR/ai/state.md" 2>/dev/null
  date +%s > "$DIR/.state_ts"
}
state_fresh() {
  # rc0 = state.md є і молодший за 48год
  [ -s "$DIR/ai/state.md" ] || return 1
  TS=$(cat "$DIR/.state_ts" 2>/dev/null)
  case "$TS" in ''|*[!0-9]*) return 1 ;; esac
  [ $(( $(date +%s) - TS )) -le 172800 ]
}
act_log() {
  # $1=команда $2=rc -> механічний журнал дій агента (памʼять "що я робив")
  printf '%s | %s => rc=%s\n' "$(date '+%d.%m %H:%M')" "$(printf '%s' "$1" | tr '\n\t' '  ' | head -c 120)" "${2:-?}" >> "$DIR/ai/actions.log" 2>/dev/null
  tail -c 4000 "$DIR/ai/actions.log" > "$DIR/ai/actions.log.t" 2>/dev/null && mv "$DIR/ai/actions.log.t" "$DIR/ai/actions.log"
}

# --- VPN: Cloudflare WARP (детерміновані дії замість AI-агента) ---
warp_status_text() {
  # -> текст стану WARP у OUTW (0 токенів)
  if ! uci -q get network.warp >/dev/null 2>&1; then
    OUTW="$(t vpn_title)

$(t v_noconf)"
    return
  fi
  RA=$(uci -q get network.@wireguard_warp[0].route_allowed_ips 2>/dev/null)
  PBRF="$DIR/.pbr_active"
  if [ -f "$PBRF" ] && [ "$(cat "$PBRF" 2>/dev/null)" = "1" ]; then
    MODE=$(t v_mode_pbr)
  elif [ "${RA:-0}" = "1" ]; then
    MODE=$(t v_mode_all)
  else
    MODE=$(t v_mode_idle)
  fi
  ST=$(t v_s_off)
  TRC=""
  if command -v wg >/dev/null 2>&1 && ip link show warp >/dev/null 2>&1; then
    HS=$(wg show warp latest-handshakes 2>/dev/null | awk '{print $2}')
    if [ -n "$HS" ] && [ "$HS" != "0" ]; then
      ST=$(t v_s_on)
      TRC=$(curl -s --max-time 8 --interface warp https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null | grep -E '^(warp|ip)=' | tr '\n' '; ')
    fi
  fi
  PORT=$(uci -q get network.@wireguard_warp[0].endpoint_port 2>/dev/null)
  OUTW="$(t vpn_title)

$ST · порт ${PORT:-2408} · $MODE
${TRC:+<code>$TRC</code>}"
}

fmt_speed() {
  # $1=байти -> "8.4 МБ" (для таблиць MTU-тесту)
  awk -v b="${1:-0}" 'BEGIN{printf "%.1f МБ", b/1048576}'
}
parse_ping_avg() {
  # stdin: вивід ping -> середній RTT ("14.1") або пусто
  awk '/min\/avg\/max/ {split($4,a,"/"); print a[2]; exit}'
}

warp_mtu_script() {
  # друкує фоновий MTU-тест: 1420/1400/1380/1280 -> швидкість за 8с кожен;
  # наприкінці ПОВЕРТАЄ початковий MTU (рішення про зміну — за власником кнопкою)
  cat <<'MEOF'
ORIG=$(uci -q get network.@wireguard_warp[0].mtu); ORIG=${ORIG:-1280}
OUT=""; BEST=""; BESTB=0
for M in 1420 1400 1380 1280; do
  uci set network.@wireguard_warp[0].mtu="$M"; uci commit network
  ifup warp 2>/dev/null
  HS=""; n=0
  while [ $n -lt 10 ]; do
    sleep 1; n=$((n+1))
    HS=$(wg show warp latest-handshakes 2>/dev/null | awk '{print $2}')
    [ -n "$HS" ] && [ "$HS" != "0" ] && break
  done
  if [ -z "$HS" ] || [ "$HS" = "0" ]; then
    OUT="$OUT
$M → ❌ немає handshake"
    continue
  fi
  B=$(curl --interface warp -s -o /dev/null -w '%{size_download}' --max-time 8 'https://speed.cloudflare.com/__down?bytes=50000000')
  B=${B:-0}
  OUT="$OUT
$M → $(awk -v b="$B" 'BEGIN{printf "%.1f МБ", b/1048576}')"
  if [ "$B" -gt "$BESTB" ]; then BESTB=$B; BEST=$M; fi
done
# повертаємо початковий MTU (застосування найкращого — окрема кнопка з підтвердженням)
uci set network.@wireguard_warp[0].mtu="$ORIG"; uci commit network
ifup warp 2>/dev/null
if [ -z "$BEST" ]; then
  printf '%s' "❌ Жоден MTU не дав handshake — повернув безпечний 1280." > "$DIR/.lb_out"
else
  printf '%s' "📏 MTU-тест (завантажено за 8 с через тунель):
$OUT

Найкращий: $BEST. Поточний ($ORIG) відновлено." > "$DIR/.lb_out"
fi
touch "$DIR/.lb_done"
MEOF
}

warp_ep_script() {
  cat <<'EEOF'
EPING=0; OUT=""; BESTIP=""; BESTP=999999
for IP in 162.159.192.1 162.159.192.2 162.159.192.3 162.159.192.4 162.159.192.5 engage.cloudflareclient.com; do
  R=$(ping -c 3 -W 2 "$IP" 2>/dev/null | awk '/min\/avg\/max/{split($4,a,"/");print a[2]}')
  if [ -n "$R" ]; then
    EPING=$((EPING+1))
    OUT="$OUT
$IP → $R мс"
    HIT=$(awk -v a="$R" -v b="$BESTP" 'BEGIN{print (a<b)?1:0}')
    [ "$HIT" = "1" ] && BESTP=$R && BESTIP=$IP
  else
    OUT="$OUT
$IP → ❌ 100% втрат"
  fi
done
if [ "$EPING" = "0" ]; then
  printf '%s' "❌ ICMP до Cloudflare заблоковано провайдером — пінг-тест неможливий." > "$DIR/.lb_out"
else
  printf '%s' "📡 Пінг endpoint-ів Cloudflare:
$OUT

Найшвидший: $BESTIP ($BESTP мс)." > "$DIR/.lb_out"
fi
touch "$DIR/.lb_done"
EEOF
}

parse_ip_cidr() {
  # $1=рядок -> 0= валідний IP/CIDR, 1=невалідний
  case "$1" in
    ''|*[!0-9./]*) return 1 ;;
  esac
  echo "$1" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(/([0-9]|[12][0-9]|3[012]))?$' || return 1
  IPOCT="${1%%/*}"
  A=$(echo "$IPOCT" | cut -d. -f1); B=$(echo "$IPOCT" | cut -d. -f2); C=$(echo "$IPOCT" | cut -d. -f3); D=$(echo "$IPOCT" | cut -d. -f4)
  [ "$A" -le 255 ] && [ "$B" -le 255 ] && [ "$C" -le 255 ] && [ "$D" -le 255 ] || return 1
  return 0
}

pbr_apply_script() {
  # застосовує PBR: тільки IP з blocked.list через WARP (nftables set + iptables mark + ip rule)
  cat <<'PEOF'
BFILE="/etc/tg-bot/blocked.list"
if [ ! -s "$BFILE" ]; then echo "PBR: blocked.list порожній"; exit 1; fi
# створюємо nftables set для заблокованих IP (якщо ще немає)
nft add set inet fw4 blocked_net '{ type ipv4_addr; flags interval; }' 2>/dev/null
nft flush set inet fw4 blocked_net 2>/dev/null
while IFS= read -r CIDR; do
  [ -n "$CIDR" ] && nft add element inet fw4 blocked_net "{ $CIDR }" 2>/dev/null
done < "$BFILE"
# iptables/mark: пакети до заблокованих IP отримують mark 0x1
iptables -t mangle -D PREROUTING -m set --match-set blocked_net dst -j MARK --set-mark 0x1 2>/dev/null
iptables -t mangle -A PREROUTING -m set --match-set blocked_net dst -j MARK --set-mark 0x1 2>/dev/null
# fallback: якщо iptables немає — прямий nft mark
OLDH=$(nft -a list chain inet fw4 prerouting 2>/dev/null | grep 'blocked_net' | head -1 | sed -n 's/.*handle \([0-9]*\).*/\1/p')
[ -n "$OLDH" ] && nft delete rule inet fw4 prerouting handle $OLDH 2>/dev/null
nft insert rule inet fw4 prerouting ip daddr @blocked_net meta mark set 0x1 2>/dev/null
# ip rule: mark 0x1 -> routing table 100 (warp)
ip rule del fwmark 0x1 2>/dev/null
ip rule add fwmark 0x1 lookup 100
ip route replace default dev warp table 100 2>/dev/null
echo "PBR: застосовано ($(wc -l < "$BFILE") записів)"
PEOF
}

pbr_clear_script() {
  cat <<'CEOF'
nft flush set inet fw4 blocked_net 2>/dev/null
nft delete set inet fw4 blocked_net 2>/dev/null
OLDH=$(nft -a list chain inet fw4 prerouting 2>/dev/null | grep 'blocked_net' | head -1 | sed -n 's/.*handle \([0-9]*\).*/\1/p')
[ -n "$OLDH" ] && nft delete rule inet fw4 prerouting handle $OLDH 2>/dev/null
ip rule del fwmark 0x1 2>/dev/null
echo "PBR: правила прибрано"
CEOF
}

spd_make_bar() {
  # $1=bytes $2=total -> "▰▰▰▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱"
  awk -v cur="$1" -v total="$2" 'BEGIN{
    pct=int(cur/total*100); if(pct>100) pct=100
    filled=int(pct*20/100); empty=20-filled
    for(i=0;i<filled;i++) printf "▰"
    for(i=0;i<empty;i++) printf "▱"
  }'
}

spd_run_one() {
  # $1=mode(direct|warp) $2=token $3=chatid $4=msgid
  # Завантажує10МБ, оновлює повідомлення кожні 2с; результ вивід в stdout
  MODE="$1" TOKEN="$2" CHAT_ID="$3" MSG_ID="$4"
  URL="https://speed.cloudflare.com/__down?bytes=10485760"
  TOTAL=10485760
  TMPF="/tmp/spd_$$.bin"
  LABEL="🌐 Напряму"; [ "$MODE" = "warp" ] && LABEL="📡 Через WARP"

  if [ "$MODE" = "warp" ]; then
    curl -s -o "$TMPF" --max-time 30 --interface warp "$URL" &
  else
    curl -s -o "$TMPF" --max-time 30 "$URL" &
  fi
  CURL_PID=$!
  START=$(date +%s)

  while kill -0 $CURL_PID 2>/dev/null; do
    sleep 2
    NOW=$(date +%s); ELAPSED=$((NOW-START)); [ "$ELAPSED" -eq 0 ] && ELAPSED=1
    BYTES=$(wc -c < "$TMPF" 2>/dev/null); BYTES=${BYTES:-0}
    SPEED=$(awk "BEGIN{printf \"%.1f\",$BYTES/1048576/$ELAPSED}")
    DONE_MB=$(awk "BEGIN{printf \"%.1f\",$BYTES/1048576}")
    BAR=$(spd_make_bar "$BYTES" "$TOTAL")
    TEXT=$(printf '%s\n%s\n⬇️ %s МБ / 10 МБ · %dс · %s МБ/с' "$LABEL" "$BAR" "$DONE_MB" "$ELAPSED" "$SPEED")
    # editMessageText напряму через curl
    printf '{"chat_id":"%s","message_id":%s,"text":"%s"}' "$CHAT_ID" "$MSG_ID" "$(printf '%s' "$TEXT" | sed 's/"/\\"/g')" > /tmp/spd_rq.json
    curl -s --max-time 5 "$API/editMessageText" -H "Content-Type: application/json" --data-binary @/tmp/spd_rq.json >/dev/null 2>&1
  done

  wait $CURL_PID 2>/dev/null
  FINAL_BYTES=$(wc -c < "$TMPF" 2>/dev/null); FINAL_BYTES=${FINAL_BYTES:-0}
  FINAL_TIME=$(($(date +%s)-START)); [ "$FINAL_TIME" -eq 0 ] && FINAL_TIME=1
  FINAL_SPEED=$(awk "BEGIN{printf \"%.1f\",$FINAL_BYTES/1048576/$FINAL_TIME}")
  FINAL_MBIT=$(awk "BEGIN{printf \"%.1f\",$FINAL_SPEED*8}")
  DONE_MB=$(awk "BEGIN{printf \"%.1f\",$FINAL_BYTES/1048576}")
  BAR=$(spd_make_bar "$TOTAL" "$TOTAL")
  RESULT=$(printf '%s\n%s\n⬇️ %s МБ · %dс · %s МБ/с (%s Мбіт)' "$LABEL" "$BAR" "$DONE_MB" "$FINAL_TIME" "$FINAL_SPEED" "$FINAL_MBIT")
  rm -f "$TMPF" /tmp/spd_rq.json
  printf '%s' "$RESULT"
}

warp_reg_script() {
  # друкує фоновий скрипт реєстрації+setup (викликається в ( ... ) & ; результат через .lb_*)
  cat <<'WEOF'
LOG=""
command -v wg >/dev/null 2>&1 || {
  AO=$(apk add wireguard-tools 2>&1 | tail -2); LOG="$LOG
apk add wireguard-tools → $AO"
}
command -v wg >/dev/null 2>&1 || {
  printf '%s' "❌ wireguard-tools не встановився.$LOG" > "$DIR/.lb_out"; touch "$DIR/.lb_done"; exit 0
}
PRIV=$(wg genkey 2>/dev/null)
PUB=$(printf '%s' "$PRIV" | wg pubkey 2>/dev/null)
TOS=$(date -u +%FT%TZ)
curl -s --max-time 20 -X POST https://api.cloudflareclient.com/v0a2158/reg \
  -H "Content-Type: application/json" -H "User-Agent: okhttp/3.12.1" \
  -d "{\"key\":\"$PUB\",\"install_id\":\"\",\"fcm_token\":\"\",\"tos\":\"$TOS\",\"model\":\"OpenWrt\",\"locale\":\"en\"}" > "$DIR/.wreg.json"
grep -q '"id"' "$DIR/.wreg.json" || {
  printf '%s' "❌ Реєстрація Cloudflare не пройшла:
$(head -c 200 "$DIR/.wreg.json")" > "$DIR/.lb_out"; touch "$DIR/.lb_done"; exit 0
}
V4=$(grep -o '"v4":"[0-9.]*"' "$DIR/.wreg.json" | head -1 | cut -d'"' -f4)
PEERPK=$(grep -o '"public_key":"[^"]*"' "$DIR/.wreg.json" | head -1 | cut -d'"' -f4)
[ -n "$V4" ] && [ -n "$PEERPK" ] || {
  printf '%s' "❌ Реєстрація пройшла, але парсинг профілю не вдався:
$(head -c 200 "$DIR/.wreg.json")" > "$DIR/.lb_out"; touch "$DIR/.lb_done"; exit 0
}
umask 077; printf '%s\n%s\n%s\n' "$PRIV" "$V4" "$PEERPK" > "$DIR/warp.reg"; rm -f "$DIR/.wreg.json"
# --- uci setup: інтерфейс БЕЗ перехоплення трафіку (route_allowed_ips=0) ---
uci -q delete network.warp >/dev/null 2>&1
while uci -q delete network.@wireguard_warp[0] >/dev/null 2>&1; do :; done
uci set network.warp=interface
uci set network.warp.proto='wireguard'
uci set network.warp.private_key="$PRIV"
uci add_list network.warp.addresses="$V4/32"
uci set network.warp.mtu='1280'
uci add network wireguard_warp >/dev/null
uci set network.@wireguard_warp[-1].public_key="$PEERPK"
uci set network.@wireguard_warp[-1].endpoint_host='engage.cloudflareclient.com'
uci set network.@wireguard_warp[-1].endpoint_port='2408'
uci add_list network.@wireguard_warp[-1].allowed_ips='0.0.0.0/0'
uci add_list network.@wireguard_warp[-1].allowed_ips='::/0'
uci set network.@wireguard_warp[-1].persistent_keepalive='25'
uci set network.@wireguard_warp[-1].route_allowed_ips='0'
uci commit network
i=0; ZF=""
while :; do N=$(uci -q get firewall.@zone[$i].name 2>/dev/null) || break
  [ "$N" = "warp" ] && ZF=$i && break; i=$((i+1)); done
[ -z "$ZF" ] && {
  uci add firewall zone >/dev/null
  Z=$(( $(uci show firewall | grep -c '=zone') - 1 ))
  uci set firewall.@zone[$Z].name='warp'
  uci set firewall.@zone[$Z].input='REJECT'
  uci set firewall.@zone[$Z].output='ACCEPT'
  uci set firewall.@zone[$Z].forward='REJECT'
  uci add_list firewall.@zone[$Z].network='warp'
  uci set firewall.@zone[$Z].masq='1'
  uci commit firewall
}
ifup warp
# --- handshake, fallback портами якщо CF блокує 2408 ---
# якщо netifd ще не знає proto wireguard (свіже встановлений пакет) — рестарт мережі
NEED_RS=""
ubus call network get_proto_handlers 2>/dev/null | grep -q wireguard || NEED_RS=1
HS=""
for PT in 2408 500 1701 4500; do
  uci set network.@wireguard_warp[-1].endpoint_port="$PT"; uci commit network
  if [ -n "$NEED_RS" ]; then
    /etc/init.d/network restart >/dev/null 2>&1
    NEED_RS=""
    sleep 25
  else
    /etc/init.d/network reload >/dev/null 2>&1
    sleep 6
  fi
  HS=$(wg show warp latest-handshakes 2>/dev/null | awk '{print $2}')
  [ -n "$HS" ] && [ "$HS" != "0" ] && break
done
state_rebuild
if [ -n "$HS" ] && [ "$HS" != "0" ]; then
  TRC=$(curl -s --max-time 8 --interface warp https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null | grep -E '^warp=|^ip=' | tr '\n' ' ')
  printf '%s' "✅ WARP створено (порт $PT). Тунель живий.
$TRC

Далі: кнопка 🟢 «Весь трафік» — пустить увесь трафік роутера через WARP (з підтвердженням і страховкою)." > "$DIR/.lb_out"
else
  printf '%s' "❌ Тунель створений, але handshake не вдався жодним портом (2408/500/1701/4500).
Можливо, провайдер блокує WireGuard або CF обмежив реєстрацію. Спробуйте пізніше." > "$DIR/.lb_out"
fi
touch "$DIR/.lb_done"
WEOF
}

skill_pick() {
  # $1=Q -> шлях до скіла за ключовими словами; порожньо/rc=1 — тема не розпізнана.
  # ASCII знижуємо tr-ом, кирилиця — парними патернами (busybox tr байтовий, UTF-8 не мапить).
  QL=$(printf '%s' "$1" | tr 'A-Z' 'a-z')
  case "$QL" in
    *wifi*|*wi-fi*|*вайфай*|*ssid*|*гостьов*|*Гостьов*|*канал*|*Канал*|*потужност*|*Потужност*|*мощность*|*скрыт*|*приховат*|*Приховат*)
      printf '%s' "$DIR/ai/skills/wifi.md"; return 0 ;;
    *wireguard*|*" wg "*|*vpn*|*VPN*|*тунел*|*Тунел*)
      printf '%s' "$DIR/ai/skills/vpn.md"; return 0 ;;
    *dns*|*dns*|*doh*|*adblock*|*реклам*|*Реклам*|*blocky*)
      printf '%s' "$DIR/ai/skills/dns.md"; return 0 ;;
    *firewall*|*фаєрвол*|*Фаєрвол*|*файрвол*|*порт*|*Порт*|*проброс*|*Проброс*|*переадрес*|*dmz*|*upnp*|*зоной*|*зона*|*зони*)
      printf '%s' "$DIR/ai/skills/firewall.md"; return 0 ;;
    *nlbw*|*sqm*|*ddns*|*apk*|*пакет*|*Пакет*|*станов*|*"init.d"*|*сервис*|*Сервис*|*сервіс*|*Сервіс*|*служб*|*package*)
      printf '%s' "$DIR/ai/skills/services.md"; return 0 ;;
    *dhcp*|*аренд*|*Аренд*|*статичн*|*Статичн*|*static*ip*|*lan*ip*|*ip*lan*|*pppoe*|*пул*|*lease*)
      printf '%s' "$DIR/ai/skills/network-dhcp.md"; return 0 ;;
    *hostname*|*ntp*|*cron*|*"led"*|*светодиод*|*світлодіод*|*Світлодіод*|*"wol"*|"wake"*|*температур*|*Температур*|*backup*|*бекап*|*Бекап*|*парол*|*Парол*)
      printf '%s' "$DIR/ai/skills/system-misc.md"; return 0 ;;
  esac
  return 1
}

# --- зовнішні промпти та скіли: файли в $DIR/ai/ мають пріоритет над вбудованими ---
# Правки core.txt / recipes.txt / skills/*.md застосовуються БЕЗ перезапуску бота.
# facts.md = статичні факти; corrections.md = виправлення від власника (самонавчання).
EMERGENCY_CORE='Ты AI-агент OpenWrt-роутера. Формат: строки CMD: <команда или -> и SAY: <ответ>. Можно несколько CMD (CMD:, CMD2:, CMD3:) — ТОЛЬКО чтение (uci show/get, cat, iwinfo, ubus call); изменения — ровно одна команда за ход. Для сложных задач первая строка PLAN: <краткий план>. Никогда не выполняй деструктивные команды (rm -rf, mkfs, sysupgrade) и не трогай сервис tg-bot.'
ai_file() { [ -s "$DIR/ai/$1" ] && cat "$DIR/ai/$1" 2>/dev/null; }
ai_rules() {
  R=$(ai_file core.txt)
  if [ -n "$R" ]; then printf '%s' "$R"; else ai_rules_embedded; fi
  F=$(ai_file facts.md); [ -n "$F" ] && printf '\n\nФАКТИ ПРО ЦЕЙ РОУТЕР:\n%s' "$F"
  T=$(ai_file topology.md); [ -n "$T" ] && printf '\n\nТОПОЛОГІЯ МЕРЕЖІ (памʼять про пристрої):\n%s' "$T"
  [ -s "$DIR/ai/corrections.md" ] && {
    C=$(utf8fix "$(tail -c 900 "$DIR/ai/corrections.md")")
    printf '\n\nВИВЧЕНІ КОРЕКЦІЇ ВЛАСНИКА (найвищий приоритет, враховуй обовʼязково):\n%s' "$C"
  }
}
ai_rules_full() {
  C=$(ai_rules); R=$(ai_file recipes.txt)
  if [ -n "$R" ]; then printf '%s\n%s' "$C" "$R"; else ai_rules_full_embedded; fi
}

uci_autocommit() {
  # Механічний гарант: будь-яка uci set/add/delete отримує commit конфігів автоматично
  case "$1" in
    *"uci commit"*|*"uci import"*) printf '%s' "$1"; return ;;
    *"uci set "*|*"uci add_list "*|*"uci add "*|*"uci delete "*|*"uci rename "*|*"uci reorder "*|"uci -q "*) ;;
    *) printf '%s' "$1"; return ;;
  esac
  CLEAN=$(printf '%s' "$1" | tr '.@[]{}();&|=' '            ')
  ADD=""
  for C in network wireless dhcp firewall system sqm ddns adblock upnpd nlbwmon https-dns-proxy; do
    case " $CLEAN " in
      *" $C "*) case " $ADD " in *" $C "*) ;; *) ADD="$ADD $C" ;; esac ;;
    esac
  done
  [ -z "$ADD" ] && { printf '%s' "$1"; return; }
  O="$1"
  for C in $ADD; do O="$O && uci commit $C"; done
  printf '%s' "$O"
}

mask_secrets() {
  # Маскує паролі/ключі у тексті відповіді моделі перед відправкою в чат
  printf '%s' "$1" \
    | sed -E "s/([Kk]ey['\"]?[ :=]+)[^'\" <&]{6,}/\1••••••/g" \
    | sed -E "s/([Pp]assword['\"]?[ :=]+)[^'\" <&]{4,}/\1••••••/g" \
    | sed -E "s/(private_key['\"]?[ :=]+)[^'\" <&]{8,}/\1••••••/g"
}

risk_backup() {
  # Знімок конфігів перед небезпечними застосуваннями; /rollback повертає останній
  TS=$(date +%H%M%S)
  mkdir -p "$DIR/rb/$TS"
  for C in network wireless dhcp firewall system sqm; do
    [ -f "/etc/config/$C" ] && cp "/etc/config/$C" "$DIR/rb/$TS/"
  done
  ls -d "$DIR"/rb/* 2>/dev/null | sort | head -n -3 | while read -r OLD; do rm -rf "$OLD"; done
  echo "$TS"
}

ai_rules_embedded() {
  # КОРОТКЕ ЯДРО: протокол + безпека + формат (летить у КОЖЕН виклик моделі)
  printf '%s' "Ты — AI-агент управления роутером ImmortalWrt 25.12 (OpenWrt, busybox ash, DSA, пакеты только apk). Одна shell-команда за ход через 'CMD:', результат вернётся как 'РЕЗУЛЬТАТ КОМАНДЫ'. WiFi-интерфейс: phy0-ap0 (скан ~5-15 сек).
Формат СТРОГО: CMD: <команда|->  и строка SAY: <ответ>.
Сканирование/клиенты Wi-Fi — ТОЛЬКО утилитой iwinfo (iwinfo phy0-ap0 scan, iwinfo phy0-ap0 assoclist). Команда 'iw' на этой прошивке недоступна.
Промежуточный SAY ≤40 символов о действии. Финальный ответ ВСЕГДА содержит сами данные (списки/числа/имена) — не обещания показать позже.
Если вывод пустой/кривой — НЕ повторяй команду, упрости следующую ('... | head -40').
УТОЧНЕНИЯ РАЗРЕШЕНЫ И ПРИВЕТСТВУЮТСЯ: если запрос неоднозначен (DNS для клиентов или роутера? какой SSID? какой IP?) или действие необратимо/рискованное — задай ОДИН короткий вопрос в SAY с 'CMD: -' вместо угадывания. Пользователь ответит следующим сообщением.
Опасное (rm -rf, mkfs, dd, sysupgrade, firstboot, пароли root, отключение файрвола) через CMD никогда — предупреди в SAY. Меняющие настройки команды — только по явной просьбе пользователя; перед действиями что рвут связь (network restart, wifi reload) предупреждай в SAY. После изменений проверяй применение.
ПРАВИЛО UCI: uci set/add БЕЗ uci commit НЕ ПРИМЕНЯЕТСЯ. Любая команда изменения настроек обязана включать commit того же конфига: 'uci set ... && uci commit network'. Не сообщай об успехе, пока не проверишь фактическое значение обратной командой (uci get / iwinfo).
ОТВЕЧАЙ НА СУТЬ ВОПРОСА: если спросили про DNS — отвечай про DNS (где применилось и почему видно/не видно в WAN), не пересказывай историю IP-изменений. Если данных мало — сделай разведочную команду и дай полный фактический ответ.
Никогда не трогай /usr/bin/tg-bot.sh, /etc/init.d/tg-bot и процессы бота — это ты сам. Пароли Wi-Fi называть только по явной просьбе владельца.
ЗАБОРОНА: никогда не предлагай пользователю идти в SSH/LuCI/терминал делать что-то вручную — ТВОЯ работа выполнять команды через CMD. Если команда не сработала — сам ищи другой способ (другая утилита, другой синтаксис). В SAY не упоминай служебные слова CMD/SAY/РЕЗУЛЬТАТ.
SAY: rich Telegram HTML — <b>заголовки</b>, списки «• », значения в <code>..</code>; никакого markdown (*#\`) и таблиц. Язык — как у пользователя (по умолчанию русский)."
}

ai_rules_full_embedded() {
  # ПОВНИЙ промпт: ядро + рецепти + факти (летить тільки на першому ході питання)
  printf '%s' "$(ai_rules)
ДОСТУПНО: uci, ubus call, iwinfo, logread, jsonfilter, curl, tar, timeout, crontab, ip, df, top, apk, nft, etherwake, free, lsmod, cat /proc/net/dev, /sys/class/leds, /sys/class/thermal. НЕТ: python jq iwlist openssl base64 sudo opkg.
РЕЦЕПТЫ:
- Диагностика: ubus call system board; logread | tail -50; dmesg | tail; df -h; free; top -bn1 | head -15; cat /proc/net/dev; ubus call network.interface dump
- JSON-фильтр jsonfilter: ключи с дефисом/спецсимволами — ТОЛЬКО скобочная нотация: ifstatus wan | jsonfilter -e '@[\"dns-server\"][*]' ; точечная запись @.dns-server[*] даёт 'Invalid escape sequence' ; ещё проще без jsonfilter: ifstatus wan | grep -A2 dns
- Wi-Fi: клиенты+сигнал: iwinfo phy0-ap0 assoclist ; скан эфира: iwinfo phy0-ap0 scan (~5-15с; поля Cell/Signal:/ESSID:/Channel: — при фильтрации бери Signal и ESSID, или просто head -40) ; SSID/пароль/канал/скрытие: uci show wireless ; менять: uci set wireless.@wifi-iface[0].ssid='..' .key='..' .hidden='1'; мощность: wireless.radio0.channel/.txpower/.htmode ; применить: uci commit wireless && wifi reload ; ГОСТЕВОЙ WIFI: uci add wireless wifi-iface (.device=radio0 .mode=ap .network=guest .ssid=.encryption=psk2 .key=..) + сеть guest (bridge 192.168.x.1/24) + firewall зона guest (input REJECT, forward в wan, masq) 
- Сеть/DHCP: uci show network ; LAN IP: network.lan.ipaddr ; пул: dhcp.@dhcp[0].start/.limit/.leasetime ; АРЕНДЫ (кто подключен): cat /tmp/dhcp.leases — формат: время MAC IP имя clientid; НЕ используй ubus call dhcp lease list (его нет на этой прошивке) ; статическая аренда: uci add dhcp host (.name=.mac=.ip) commit dhcp && dnsmasq restart ; WAN pppoe: network.wan.proto/.username/.password ; применение сети: uci commit network && /etc/init.d/network restart (рвёт связь ~30 сек — только для IP/протоколов!)
- DNS (важная разница!): ДЛЯ КЛИЕНТОВ сети: uci add_list dhcp.@dnsmasq[0].server='8.8.8.8'; uci add_list dhcp.@dnsmasq[0].server='8.8.4.4'; uci commit dhcp && /etc/init.d/dnsmasq restart — этого ДОСТАТОЧНО, network restart НЕ нужен и рвёт связь! ; для самого роутера: uci set network.wan.dns='8.8.8.8' (или lan.dns) ; проверка: uci show dhcp.@dnsmasq[0] | grep server ; апстримы WAN: ifstatus wan | jsonfilter -e '@.dns-server[*]'
- Файрвол/порты: uci show firewall ; ПРОБРОС: uci add firewall redirect (.name=.src=wan .proto='tcp udp' .src_dport=.dest_ip=.dest_port=.target=DNAT) commit firewall && firewall restart ; зоны/правила через firewall.@rule[-1]
- Пакеты/сервисы: apk update/search/add/del; список: apk list --installed --no-network ; СЕРВИСЫ: /etc/init.d/SVC start|stop|restart|enable|disable; список: ls /etc/init.d/
- Полезные пакеты: ddns-scripts, https-dns-proxy (DoH), adblock+luci-app-adblock, sqm-scripts (QoS), nlbwmon (трафик per-host), miniupnpd, etherwake
- WireGuard VPN: apk add wireguard-tools luci-proto-wireguard kmod-wireguard; network.wg0=interface proto=wireguard + секции wireguard_wg0; зона wg
- DNS/AdBlock/QoS: DoH: apk add https-dns-proxy && enable ; AdBlock: apk add adblock luci-app-adblock; uci set adblock.global.adb_enabled=1 ; SQM: apk add sqm-scripts luci-app-sqm; sqm.@queue[0] .enabled=1 .interface=wan-dev .download/.upload=~90% скорости
- Система: hostname/timezone/NTP: system.@system[0] ; CRON: (crontab -l; echo 'мин час * * * команда') | crontab - && cron restart ; LED: ls /sys/class/leds/, echo N > ИМЯ/brightness ; WoL: etherwake -i br-lan MAC ; температура: /sys/class/thermal/thermal_zone*/temp
- Бэкап: tar -czf /tmp/b.tar.gz /etc/config /etc/tg-bot
Особенность сети: провайдер FREENET даёт CGNAT IP (100.64.0.0/10) — входящие из интернета невозможны, проброс портов извне бесполезен; DDNS не поможет; для доступа извне — только исходящий WireGuard к своему VPS.
Факты: сервис бота /etc/init.d/tg-bot, скрипт /usr/bin/tg-bot.sh, конфиг /etc/config/tgbot (uci) — это ТЫ САМ, не трогай. Перед обращением к файлам/сервисам проверяй существование. Если выше есть блок \"ЗНАННЯ ПО ТЕМІ ВЖЕ НАДАНО\" — файл скілла уже в контексте, cat НЕ нужен, действуй сразу.
Пользователь просит сложную настройку — действуй сам по логике OpenWrt: разведка (uci show/ls/apk search) → изменение → проверка применения → отчёт."
}

model_list() {
  # Кандидати primary-моделі для /model (рядок=модель, без пробілів — split-safe)
  printf '%s\n%s\n%s\n%s\n' \
    "qwen/qwen3.6-27b" \
    "openai/gpt-oss-20b" \
    "openai/gpt-oss-120b" \
    "nvidia/nemotron-3-super-120b-a12b:free"
}

fast_intent() {
  # $1=Q -> ACTION | "" (нема впевненого збігу). Безкоштовний локальний класифікатор — AI не викликається.
  # Порядок важливий: devices раніше scan (бо «пристроїв у мережі»). Кирилиця — парні патерни (tr байтовий).
  case "$1" in
    *пристрій*|*Пристрій*|*пристрої*|*Пристрої*|*девайс*|*Девайс*|*"хто в мереж"*|*"хто підключен"*|*аренд*) echo devices; return ;;
    *качає*|*Качає*|*качает*|*Качает*|*"споживає трафік"*|*"більше всіх"*|*"Більше всіх"*) echo devices; return ;;
    *"скан"*|*"Скан"*|*навколо*|*сусід*|*"сильніший сигнал"*|*"найкращий сигнал"*) echo wifi_scan; return ;;
    *аптайм*|*Аптайм*|*uptime*|*"стан роутер"*|"Стан роутер"*|"як роутер"*|*навантажен*|*прошивк*|*Прошивк*|*firmware*) echo sys_info; return ;;
    *"що ти вмієш"*|*"Що ти вмієш"*|*"що вмієш"*|"команди бота"*|*допомога*|*"встановити бота"*|*"бота установить"*|*"установить бота"*|*"встановити цей бот"*) echo help; return ;;
  esac
  return 1
}

ai_intent() {
  # $1=Q -> ACTION (sys_info|devices|wifi_scan|help|unknown); класифікатор на МАЛІЙ моделі
  # (ai_model_classifier, дефолт llama-3.1-8b-instant) — свій безкоштовний TPD-бакет Groq,
  # основна квота не витрачається. Фолбек: основна модель, якщо Groq-ключа нема.
  ITP=$(ai_file intent.txt)
  [ -z "$ITP" ] && { echo unknown; return; }
  IM=$(uci -q get tgbot.config.ai_model_classifier)
  IU=$(uci -q get tgbot.config.ai_url); [ -z "$IU" ] && IU="https://api.groq.com/openai/v1/chat/completions"
  IK=$(uci -q get tgbot.config.ai_key)
  if [ -z "$IM" ] || [ -z "$IK" ]; then
    IM=$(uci -q get tgbot.config.ai_model); [ -z "$IM" ] && IM="qwen/qwen3.6-27b"
    IU=$(uci -q get tgbot.config.ai_url); [ -z "$IU" ] && IU="https://openrouter.ai/api/v1/chat/completions"
    IK=$(uci -q get tgbot.config.ai_key)
  fi
  # qwen: reasoning_effort=none (hidden ненадійний — іноді порожній content навіть на finish:stop);
  # gpt-oss: low. Класифікації міркування не потребують.
  printf '{"model":"%s","max_tokens":250%s,"messages":[{"role":"system","content":"%s"},{"role":"user","content":"%s"}]}' \
    "$IM" "$(case $IM in *qwen*) echo ',"reasoning_effort":"none"' ;; *gpt-oss*) echo ',"reasoning_effort":"low"' ;; esac)" \
    "$(jesc "$ITP")" "$(jesc "$(utf8fix "$1")")" > "$DIR/.iq"
  IR=$(curl -s --max-time 30 "$IU" \
    -H "Authorization: Bearer $IK" \
    -H "Content-Type: application/json" \
    --data-binary "@$DIR/.iq")
  rm -f "$DIR/.iq"
  IA=$(printf '%s' "$IR" | jsonfilter -e '$.choices[0].message.content' 2>/dev/null)
  ACT=$(printf '%s' "$IA" | tr -d '`' | grep -o '"action"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"//; s/"$//')
  tok_log "classifier/$IM" \
    "$(printf '%s' "$IR" | jsonfilter -e '$.usage.prompt_tokens' 2>/dev/null)" \
    "$(printf '%s' "$IR" | jsonfilter -e '$.usage.completion_tokens' 2>/dev/null)"
  echo "${ACT:-unknown}"
}

brk_file() { printf '%s/.mf_%s' "$DIR" "$(printf '%s' "$1" | md5sum | cut -c1-8)"; }
brk_ok() { B=$(brk_file "$1"); [ -f "$B" ] && [ "$(cat "$B" 2>/dev/null)" -gt "$(date +%s)" ] 2>/dev/null && return 1; return 0; }
brk_set() { B=$(brk_file "$1"); echo $(( $(date +%s) + $2 )) > "$B"; }

ai_call() {
  # $1=system $2=user [$3=max_tokens; дефолт 1200] -> ANS (пусто = ошибка, детали в lasterr)
  MTOK="${3:-1200}"
  AIMODEL=$(uci -q get tgbot.config.ai_model)
  [ -z "$AIMODEL" ] && AIMODEL="qwen/qwen3.6-27b"
  ALTMODEL=$(uci -q get tgbot.config.ai_model_alt)
  [ -z "$ALTMODEL" ] && ALTMODEL="nvidia/nemotron-3-super-120b-a12b:free"
  # Резервний провайдер (інша квота-бакет): ai_url2/ai_key2/ai_model2
  AIURL2=$(uci -q get tgbot.config.ai_url2)
  AIKEY2=$(uci -q get tgbot.config.ai_key2)
  [ -z "$AIURL2" ] && [ -n "$AIKEY2" ] && AIURL2="https://openrouter.ai/api/v1/chat/completions"
  # Третій провайдер — Gemini (своя безкоштовна квота; OpenRouter лишаємо на крайній випадок)
  AIKEY3=$(uci -q get tgbot.config.ai_key3)
  AIMODEL3=$(uci -q get tgbot.config.ai_model3)
  [ -z "$AIMODEL3" ] && AIMODEL3="gemini-3.6-flash"
  AIURL3="https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
  # Fallback-ланцюг Groq (у кожної СВІЙ денний ліміт TPD): великі моделі — для складних випадків
  GCHAIN=$(uci -q get tgbot.config.ai_groq_chain)
  [ -z "$GCHAIN" ] && GCHAIN="qwen/qwen3.6-27b openai/gpt-oss-120b"
  AIURL=$(uci -q get tgbot.config.ai_url)
  [ -z "$AIURL" ] && AIURL="https://openrouter.ai/api/v1/chat/completions"
  AKEY=$(uci -q get tgbot.config.ai_key)
  ANS=""; R=""
  # Ланцюг: primary (дешева) → Groq-фолбеки (свої TPD) → Gemini → OpenRouter. Без ретраїв тієї ж моделі.
  for TRY in primary $GCHAIN gem or; do
    case $TRY in
      primary) M="$AIMODEL"; U="$AIURL"; K="$AKEY" ;;
      gem) [ -z "$AIKEY3" ] && continue; M="$AIMODEL3"; U="$AIURL3"; K="$AIKEY3" ;;
      or) [ -z "$AIKEY2" ] && continue; M="$ALTMODEL"; U="${AIURL2:-$AIURL}"; K="$AIKEY2" ;;
      *)  M="$TRY"; U="$AIURL"; K="$AKEY" ;;
    esac
    # безключові ланки пропускаємо одразу (напр. primary порожній, а є лише Gemini)
    [ -z "$K" ] && { alog MODEL "skip $TRY (no key)"; continue; }
    # Circuit breaker: модель що щойно зламалась/лімітувалась пропускається (крім останнього рубежу)
    if [ "$TRY" != "or" ] && ! brk_ok "$M"; then alog MODEL "skip $M (breaker)"; continue; fi
    case $M in
      *qwen*) EXTRA=',"reasoning_effort":"none"' ;;
      *gpt-oss*) EXTRA=',"reasoning_effort":"low"' ;;
      *gemini*) EXTRA=',"reasoning_effort":"low"' ;;
      *) EXTRA="" ;;
    esac
    printf '{"model":"%s","max_tokens":%s%s,"messages":[{"role":"system","content":"%s"},{"role":"user","content":"%s"}]}' \
      "$M" "$MTOK" "$EXTRA" "$(jesc "$(utf8fix "$1")")" "$(jesc "$(utf8fix "$2")")" > "$DIR/.aiq"
    R=$(curl -s --max-time 90 "$U" \
      -H "Authorization: Bearer $K" \
      -H "Content-Type: application/json" \
      --data-binary "@$DIR/.aiq")
    ANS=$(printf '%s' "$R" | jsonfilter -e '$.choices[0].message.content' 2>/dev/null)
    TOK=$(printf '%s' "$R" | jsonfilter -e '$.usage.total_tokens' 2>/dev/null)
    PTK=$(printf '%s' "$R" | jsonfilter -e '$.usage.prompt_tokens' 2>/dev/null)
    CTK=$(printf '%s' "$R" | jsonfilter -e '$.usage.completion_tokens' 2>/dev/null)
    if [ -n "$ANS" ]; then
      alog MODEL "try=$TRY model=$M ans=${#ANS} tokens=${TOK:-?}"
      tok_log "$M" "$PTK" "$CTK"
      break
    fi
    alog MODEL "try=$TRY model=$M FAILED"
    case "$R" in
      *"Rate limit"*|*"rate limit"*|*quota*) brk_set "$M" 600 ;;
      *) brk_set "$M" 90 ;;
    esac
  done
  rm -f "$DIR/.aiq"
  [ -z "$ANS" ] && printf '%s' "$R" | head -c 300 > "$DIR/lasterr"
  case "$R" in
    *"Rate limit"*|*"rate limit"*|*'"code":429'*|"quota"*)
      ANS="$(t ai_429)"
      ;;
  esac
  ANS=$(printf '%s' "$ANS" | sed 's/```[a-zA-Z]*//g; s/```//g; /<think>/,/<\/think>/d; s/<think>.*$//')
}

key_slot() {
  # $1=ключ -> назва слота (ai_key|ai_key2|ai_key3) або "" ; та сама логіка в install.sh
  case "$1" in
    gsk_*) echo ai_key ;;
    sk-or-v1*) echo ai_key2 ;;
    ??*) echo ai_key3 ;;
    *) return 1 ;;
  esac
}

key_cmd() {
  # /key            -> статус слотів (замасковано)
  # /key <КЛЮЧ>     -> зберегти у свій слот за префіксом; БЕЗ AI — працює завжди
  K=$(printf '%s' "$1" | awk '{print $2}')
  if [ -z "$K" ]; then
    S=""
    for SLOT in ai_key ai_key2 ai_key3; do
      V=$(uci -q get tgbot.config.$SLOT)
      [ -n "$V" ] && S="$S\n• $SLOT: ${V%????????}…"
    done
    reply "🔑 AI-ключі:${S:-\n• жодного.}
Додати: /key gsk_… (Groq) | /key sk-or-v1… (OpenRouter) | /key інший (Gemini)"
    return
  fi
  case "$K" in
    *[!A-Za-z0-9_.\-]*) reply "🚫 Ключ містить недопустимі символи."; return ;;
  esac
  [ "${#K}" -lt 20 ] && { reply "🚫 Занадто короткий для ключа."; return; }
  SLOT=$(key_slot "$K") || { reply "🚫 Невідомий формат ключа. Підтримую: gsk_* / sk-or-v1* / інший (Gemini)."; return; }
  uci set tgbot.config.$SLOT="$K"
  case $SLOT in
    ai_key) uci -q get tgbot.config.ai_url >/dev/null || { uci set tgbot.config.ai_url="https://api.groq.com/openai/v1/chat/completions"; uci -q get tgbot.config.ai_model >/dev/null || uci set tgbot.config.ai_model="qwen/qwen3.6-27b"; } ;;
    ai_key2) [ -z "$(uci -q get tgbot.config.ai_url2)" ] && uci set tgbot.config.ai_url2="https://openrouter.ai/api/v1/chat/completions" ;;
    ai_key3) [ -z "$(uci -q get tgbot.config.ai_model3)" ] && uci set tgbot.config.ai_model3="gemini-3.6-flash" ;;
  esac
  uci commit tgbot
  alog CONF "/key → $SLOT (довжина ${#K})"
  reply "✅ Ключ збережено у <code>$SLOT</code>. Ланцюг підхопить його одразу, рестарт не потрібен."
}

is_mut() {
  # Тільки для читання — НЕ мутують, підтвердження не потрібне:
  case "$1" in
    "uci show"*|"uci -q show"*|"uci get"*|"uci -q get"*|"uci -q "*|"ubus call"*) return 1 ;;
    "apk info"*|"apk list"*|"apk search"*) return 1 ;;
  esac
  case "$1" in
    "uci "*|reboot*|service*|/etc/init.d/*|"wifi "*|ifup*|ifdown*|"opkg "*|"apk "*|\
    "rm "*|"mv "*"cp "*"ln "*"mkdir "*"touch "*|passwd*|chmod*|chown*|\
    mount*|umount*|sysupgrade*|firstboot*|"dd "*|mkfs*|"mtd "*|insmod*|rmmod*|\
    crontab*|"flash"*|swconfig*) return 0 ;;
    *) return 1 ;;
  esac
}

sanitize_cmd() {
  # $1=CMD -> rc0 дозволено / rc1 відхилено. Захист у глибину для команд від моделі:
  # підстановки та ; закривають обхід regex-банів ai_run, невидимий Unicode — спуфінг.
  # Пайпи НЕ баняться (скіли самі використовують "| head"). Ідея: utakamo/oasis security_guard.
  # ЛАПКИ: ; всередині '…' або "…" — літерал (напр. sed 's/a;b/') — НЕ відхиляємо.
  NQ=$(printf '%s' "$1" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")
  case "$NQ" in
    *';'*) return 1 ;;
  esac
  # підстановки перевіряємо по сирому рядку ($(...) всередині подвійних лапок виконується!)
  case "$1" in
    *'`'*|*'$('*|*'${'*) return 1 ;;
  esac
  # керуючі байти — легітимних команд з ними нема
  if printf '%s' "$1" | LC_ALL=C grep -q "$(printf '[\001-\010\013\014\016-\037]')"; then return 1; fi
  # zero-width/RTL-спуф: усі U+2000-U+206F несуть байти E2 80 — в командах не бувають
  if printf '%s' "$1" | LC_ALL=C grep -qF "$(printf '\342\200')"; then return 1; fi
  # дозволяємо && між командами, але не поодинокий & (фоновий запуск)
  FRAG="$1"
  while :; do
    case "$FRAG" in
      *'&&'*) CUR="${FRAG%%&&*}"; FRAG="${FRAG#*&&}" ;;
      *)      CUR="$FRAG"; FRAG="" ;;
    esac
    # 2>&1 / >&2 — легітимні редиректи, не фоновий & : зрізаємо перед перевіркою &
    CURCHK=$(printf '%s' "$CUR" | sed -E 's/[0-9]?>&[0-9]+//g')
    case "$CURCHK" in *'&'*) return 1 ;; esac
    [ -z "$FRAG" ] && break
  done
  return 0
}

unglue_cmd() {
  # $1=ANS -> stdout. Модель інколи клеїть хвіст «... CMD: [-]» (інколи в тегах) в кінець SAY.
  # Розрізаємо: текст лишається, а «CMD: -» стає окремим рядком — парсер дає чистий break без сміття в SAY.
  printf '%s' "$1" | awk '
    { L[NR]=$0 }
    END {
      n=NR; g=0;
      if (n>=1) {
        l=L[n];
        if (match(l, /(^|[ >])CMD/)) {
          cs=RSTART; ce=RSTART+RLENGTH-1;
          if (cs>2) {
            d=substr(l,ce+1); dd=d;
            gsub(/<[^>]*>|<\/?[a-z]+$|[[:space:]]|[-—–:]/,"",dd);
            if (dd=="") {
              g=1;
              h=substr(l,1,cs);
              sub(/[[:space:]]+$/,"",h);
              sub(/[[:space:]]*(<[^>]*>[[:space:]]*)+/,"",h);
              sub(/<[^>]*>?[[:space:]]*$/,"",h);
              for(i=1;i<n;i++) print L[i];
              print h;
              print "CMD: -";
            }
          }
        }
      }
      if (!g) for(i=1;i<=n;i++) print L[i];
    }'
}

learn_note() {
  # $1=тип(FAIL|OK|FIX) $2=текст -> журнал уроків $DIR/ai/mistakes.md (хвостом, ліміт ~140 рядків)
  MF="$DIR/ai/mistakes.md"
  mkdir -p "$DIR/ai" 2>/dev/null
  printf '%s | %s | %s\n' "$(date '+%d.%m %H:%M')" "$1" "$2" >> "$MF" 2>/dev/null || return 0
  [ "$(wc -l < "$MF" 2>/dev/null)" -gt 140 ] && { tail -n 100 "$MF" > "$MF.new" && mv "$MF.new" "$MF"; }
}

lessons_fetch() {
  # кешований (24год) хвіст спільних уроків з GitHub prompts/learned/lessons.md; офлайн/404 = тихо ""
  # Санітизація: utf8fix + викид керуючих байтів і тегів — контекст іде в промпт моделі
  LF="$DIR/kbcache/_lessons.md"
  if [ -s "$LF" ] && [ "$(find "$DIR/kbcache" -name '_lessons.md' -mmin -1440 2>/dev/null | wc -l)" -ge 1 ]; then
    utf8fix "$(tail -c 1200 "$LF")" | tr -d '\000-\010\013\014\016-\037' | sed 's/[<>]//g'
    return 0
  fi
  mkdir -p "$DIR/kbcache" 2>/dev/null || return 0
  curl -fsSL --max-time 8 "https://raw.githubusercontent.com/dneese/telegram-bot-openwrt/master/prompts/learned/lessons.md" 2>/dev/null | tail -c 1200 > "$LF.tmp" || { rm -f "$LF.tmp"; return 0; }
  [ -s "$LF.tmp" ] && mv "$LF.tmp" "$LF"
  utf8fix "$(tail -c 1200 "$LF")" | tr -d '\000-\010\013\014\016-\037' | sed 's/[<>]//g'
}

gh_sync_lessons() {
  # Пуш уроків у GitHub Contents API (потрібен uci tgbot.config.gh_token). Не частіше ніж раз на годину.
  GT=$(uci -q get tgbot.config.gh_token)
  [ -z "$GT" ] && return 0
  TSF="$DIR/.gh_les_ts"
  [ -f "$TSF" ] && [ $(( $(date +%s) - $(cat "$TSF") )) -lt 3600 ] && return 0
  SRC="$DIR/ai/mistakes.md"; [ -s "$SRC" ] || return 0
  B64=$(tail -n 80 "$SRC" | base64 2>/dev/null | tr -d '\n') ; [ -z "$B64" ] && return 0
  date +%s > "$TSF"
  REPO="dneese/telegram-bot-openwrt"; API="https://api.github.com/repos/$REPO/contents/prompts/learned/lessons.md"
  SHA=$(curl -fsSL --max-time 15 -H "Authorization: Bearer $GT" "$API" 2>/dev/null | jsonfilter -e '$.sha' 2>/dev/null)
  JS="{\"message\":\"bot lessons auto-sync $(date '+%d.%m %H:%M')\",\"content\":\"$B64\"${SHA:+,\"sha\":\"$SHA\"}}"
  printf '%s' "$JS" > "$DIR/.gh_les.json"
  curl -s --max-time 20 -X PUT -H "Authorization: Bearer $GT" \
    -H "Content-Type: application/json" --data-binary "@$DIR/.gh_les.json" "$API" >/dev/null 2>&1
  rm -f "$DIR/.gh_les.json"
  alog LEARN "synced lessons to github (rc=$?)"
}

cmd_banned() {
  # $1=CMD -> 0=заборонена. Жорсткі бани поверх sanitize_cmd (деструктив/ескалація).
  # wget/curl З пайпом НЕ баняться (шаблон KB-феча сам так працює); досі заборонено |sh.
  # ІНЦИДЕНТ 24.08: nft flush table витер fw4 при буті -> інтернет зник. Такі команди — ЗАВЖДИ бан.
  printf '%s' "$1" | grep -qE '(^|[;&[:space:]])rm +-[a-zA-Z]*r[a-zA-Z]* *f?|mkfs|dd +if=|dd +of=/dev/|sysupgrade|firstboot|[|][[:space:]]*(ba|a)?sh([[:space:]]|$)|nft +flush|iptables +[-]F([[:space:]]|$)|nft +delete +set|nft +delete +rule|ip +rule +del'
}

ai_run() {
  if cmd_banned "$1"; then
    OUT="ОТКАЗ: запрещённая команда"
    return
  fi
  if command -v timeout >/dev/null 2>&1; then
    OUT=$(timeout 60 sh -c "$1" 2>&1); RC=$?
  else
    OUT=$(sh -c "$1" 2>&1); RC=$?
  fi
  OUT=$(printf '%s' "$OUT" | head -c 3500)
  if [ -z "$OUT" ]; then
    if [ "$RC" = "0" ]; then
      OUT="(виконано успішно, виводу немає)"
    else
      OUT="(помилка, код виходу $RC)"
    fi
  fi
  # самонавчання: невдала команда = урок (щоб модель бачила свої провали пізніше)
  [ "$RC" != "0" ] && learn_note FAIL "$(printf '%s' "$1" | head -c 160) => rc=$RC $(printf '%s' "$OUT" | head -c 80)"
}

kb_pick() {
  # $1=Q -> тема БАЗИ ЗНАНЬ GitHub (kb/*.md) або "" — синхронно зі skill_pick-темами
  case "$1" in
    *wifi*|*Wifi*|*WiFi*|*"5ГГц"*|*"2.4"*|*радіо*) echo wireless ;;
    *wireguard*|*WireGuard*|*WARP*|*warp*) echo wireguard ;;
    *vk.com*|*вконтакт*|*ВКонтакт*|*"вк "*|*заблокован*|*Заблокован*|*розблокув*|*обійти\ блокуванн*|*zaborona*|*Zaborona*) echo zaborona ;;
    *openvpn*|*OpenVPN*|*tailscale*|*Tailscale*|*zerotier*|*ZeroTier*) echo vpnother ;;
    *dns*|*DNS*|*adblock*|*DoH*|*dnsmasq*) echo dns ;;
    *firewall*|*фаєрвол*|*Фаєрвол*|*проброс*|*port\ forward*|*DMZ*) echo firewall ;;
    *SQM*|*sqm*|*QoS*|*ddns*|*DDNS*|*UPnP*|*WoL*|*USB*) echo services ;;
    *apk*|*пакет*|*Пакет*|*встанови*|*Встанови*|*nlbwmon*) echo packages ;;
    *не\ працює*|*відвалюється*|*пропада*|*обрив*|*лагає*|*тормозить*|*повільн*|*діагностик*) echo diagnostics ;;
    *безпек*|*харденінг*|*sysupgrade*|*оновленн*) echo security ;;
    *повільн*|*швидкодія*|*offload*|*оптимізац*) echo performance ;;
    *vlan*|*VLAN*|*DSA*|*маршрут*|*multi-wan*|*mwan*) echo network ;;
  esac
  return 1
}

kb_fetch() {
  # $1=тема -> stdout вміст (≤3400Б) з кешу $DIR/kbcache (TTL 7днів) або GitHub; фейл = тихо ""
  [ -z "$1" ] && return 0
  KC="$DIR/kbcache"; KF="$KC/$1.md"
  if [ -s "$KF" ] && [ "$(find "$KC" -name "$1.md" -mmin -10080 2>/dev/null | wc -l)" -ge 1 ]; then
    cat "$KF"; return 0
  fi
  mkdir -p "$KC" 2>/dev/null || return 0
  curl -fsSL --max-time 8 "https://raw.githubusercontent.com/dneese/telegram-bot-openwrt/master/prompts/kb/$1.md" 2>/dev/null | head -c 3400 > "$KF.tmp" || { rm -f "$KF.tmp"; return 0; }
  [ -s "$KF.tmp" ] && mv "$KF.tmp" "$KF"
  cat "$KF" 2>/dev/null
}

qmatch() {
  # $1=Q -> тема швидкої відповіді з uci БЕЗ AI | rc1 = нема впевненого збігу
  case "$1" in
    *пароль*|*Пароль*|*passw*|*Passw*)
      case "$1" in *wifi*|*WiFi*|*WIFI*|*вайфай*|*"wi-fi"*|*Wi-Fi*|*мереж*) echo wifi_pass; return ;; esac ;;
  esac
  case "$1" in
    *dns*|*DNS*|*ДНС*)
      case "$1" in *як*|*Яки*|*яки*|*что*|*Що*|*шо*|*сервер*|*Сервер*|*налашту*|*стоит*|*стоїть*|*використ*) echo dns_cfg; return ;; esac ;;
  esac
  case "$1" in
    *користувач*|*Користувач*|*юзер*|*Юзер*|*users*|*Users*) echo users; return ;;
  esac
  case "$1" in
    *температур*|*Температур*|*перегрі*|*Перегрі*|*перегріва*|*гріється*|*грілк*|*градус*|*temp*) echo q_temp; return ;;
  esac
  case "$1" in
    *ram*|*RAM*|*оперативн*|*Оперативн*|*"вільне місце"*|*"Вільне місце"*|*диск*|*Диск*|*сховищ*) echo q_res; return ;;
  esac
  case "$1" in
    *публічн*|*Публічн*|*публичн*|*"мій ip"*|*"Мій IP"*|"my ip"|*"зовнішній ip"*|*"білий ip"*) echo q_pubip; return ;;
  esac
  return 1
}

quick_uci() {
  # $1=тема з qmatch -> надсилає відповідь з uci; жодного токена
  case "$1" in
    wifi_pass)
      O=""
      for S in $(uci show wireless 2>/dev/null | grep "=wifi-iface" | cut -d. -f2); do
        SS=$(uci -q get wireless.$S.ssid); KY=$(uci -q get wireless.$S.key); EN=$(uci -q get wireless.$S.encryption)
        BAND=2.4G; [ "$(uci -q get wireless.$S.device)" = "radio1" ] && BAND="5G"
        [ -n "$SS" ] && O="$O
🔒 <b>$SS</b> ($BAND): <code>$KY</code>"
      done
      [ -n "$O" ] && send_rich "<b>Wi-Fi паролі</b>$O
<i>Показано власнику.</i>" || reply "$(t ai_noans)"
      ;;
    dns_cfg)
      UP=$(uci -q get dhcp.@dnsmasq[0].server 2>/dev/null | tr ' ' '\n' | sed "s/'//g" | tr '\n' ' ')
      DO6=$(uci -q get dhcp.lan.dhcp_option 2>/dev/null)
      send_rich "<b>DNS зараз</b>
• Вгору (dnsmasq): <code>${UP:-авто від провайдера}</code>
${DO6:+• DHCP клієнтам: <code>$DO6</code>}
• Резолвер роутера: <code>127.0.0.1:53</code>"
      ;;
    users)
      U=$(awk -F: '$3>=1000 && $7!~/nologon|false/{printf "• %s (home: %s)\n",$1,$6}' /etc/passwd 2>/dev/null)
      DK=$(wc -l < /etc/dropbear/authorized_keys 2>/dev/null || echo 0)
      send_rich "<b>Користувачі системи</b>
${U:-• лише root}
• SSH-ключів dropbear: <code>$DK</code>"
      ;;
    q_temp)
      T=""
      for TZ in /sys/class/thermal/thermal_zone*/temp; do
        [ -r "$TZ" ] || continue
        V=$(awk '{printf "%d", $1/1000}' "$TZ" 2>/dev/null); ZN=$(basename "$(dirname "$TZ")")
        [ -n "$V" ] && T="$T
• $ZN: <code>${V}°C</code>"
      done
      [ -n "$T" ] && send_rich "$(printf "$(t q_temp)" "$T")" || reply "$(t ai_noans)"
      ;;
    q_res)
      RAM=$(free | awk '/Mem:/ {printf "%d/%d МБ (%d%%)", $3/1024, $2/1024, $3*100/$2}')
      DSK=$(df -h / | awk 'NR==2{print $3"/"$2" ("$5")"}')
      LD=$(cut -d' ' -f1-3 /proc/loadavg 2>/dev/null)
      send_rich "$(printf "$(t q_res)" "$RAM" "$DSK" "$LD")"
      ;;
    q_pubip)
      WIP=$(ip addr show wan 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1)
      CG=""
      case "$WIP" in 100.6[4-9].*|100.7*|100.8*|100.9*|100.1[01][0-9].*|100.12[0-7].*) CG="$(t q_cgnat)" ;; esac
      send_rich "$(printf "$(t q_pubip)" "${WIP:-невідомо}" "$CG")"
      ;;
  esac
}

ai_agent() {
  # ворота: хоча б ОДИН ключ будь-якого провайдера (Groq/OpenRouter/Gemini)
  [ -z "$(uci -q get tgbot.config.ai_key)" ] && \
  [ -z "$(uci -q get tgbot.config.ai_key2)" ] && \
  [ -z "$(uci -q get tgbot.config.ai_key3)" ] && {
    reply "$(t ai_nokey)"
    return
  }
  Q=$(printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  alog Q "user: $Q"
  # --- САМОНАВЧАННЯ: виправлення власника → corrections.md (підсилається завжди) ---
  case "$Q" in
    *не\ вірно*|*не\ правильно*|*Невірно*|*неправильн*|*Неправильн*|*ти\ казав*|*Ти\ казав*|*ти\ сказав*|*Ти\ сказав*|*помилк*|*Помилк*|*ти\ ж\ сам*|*верни\ назад*|*Верни\ назад*|*знову\ не\ працює*|*Знову\ не\ працює*|*не\ те\ зробив*)
      [ -s "$DIR/aihist" ] && {
        { echo "=== $(date '+%d.%m %H:%M') виправлення:"; tail -n 4 "$DIR/aihist"; } >> "$DIR/ai/corrections.md" 2>/dev/null
        L=$(tail -n 4 "$DIR/aihist" | head -c 200); learn_note FIX "корекція власника: $L"
        gh_sync_lessons &
        alog LEARN "записано корекцію з діалогу"
      }
      ;;
    *"все працює"*|*"працює, дякую"*|*"дякую, працює"*|*"тепер працює"*|"Тепер працює"*|*"працює!"*)
      [ -s "$DIR/.lastconf" ] && {
        LC=$(sed -n '1p' "$DIR/.lastconf" | head -c 160)
        [ -n "$LC" ] && { learn_note OK "спрацювало: $LC"; gh_sync_lessons & alog LEARN "позитивний рецепт зафіксовано"; }
      }
      ;;
  esac
  # --- ШВИДКИЙ ШЛЯХ: класифікація наміру (~250 токенів замість ~3000) ---
  case "$Q" in
    "/ai"|"/ai "*|"ai"|""|"off") ;;   # командні/порожні — без класифікатора
    *)
      ACT=$(fast_intent "$Q")
      [ -z "$ACT" ] && ACT=$(ai_intent "$Q")
      # нуль-токеновий шар: прості факти з uci напряму
      QT=$(qmatch "$Q") && { alog FINAL "quick:$QT"; quick_uci "$QT"; return; }
      alog INTENT "action=$ACT"
      case "$ACT" in
        sys_info)
          alog FINAL "fast sys_info"
          OUTS="$(status_text)"; send_rich "$OUTS" || reply_rich "$OUTS"
          return ;;
        devices)
          alog FINAL "fast devices"
          OUTD="$(devices_text)"; send_rich "$OUTD" || reply_rich "$OUTD"
          return ;;
        wifi_scan)
          alog FINAL "fast scan"; cmd_scan; return ;;
        help)
          alog FINAL "fast help"; send_menu "$(help_text)"; return ;;
      esac
      ;;
  esac
  if [ "$Q" = "off" ]; then
    rm -f "$DIR/aimode"
    reply "$(t ai_exit)"
    return
  fi
  [ -z "$Q" ] && { reply "$(t ai_hint)"; return; }
  # Fast-path: питання про долю свіжої (<5 хв) PEND-команди — відповідаємо без AI
  if [ -s "$DIR/aipend" ]; then
    _PT=$(cat "$DIR/.apts" 2>/dev/null)
    [ -z "$_PT" ] && _PT=0
    if [ $(( $(date +%s) - _PT )) -le 300 ]; then
      _PC=$(utf8fix "$(cat "$DIR/aipend")")
      case "$(printf '%s' "$Q" | tr 'A-Z' 'a-z')" in
        *олучилось*|*ийшло*|*отово*|*иконано*|*аботает*|*рацю*|*спрацюва*|*"did it"*|*done?*|*ок?*)
          alog INTENT "pend_hint"
          reply "$(printf "$(t pend_hint)" "$(esc "$_PC")")"
          return ;;
      esac
    fi
  fi
  reply "$(t ai_think)"
  ( N=0; while [ $N -lt 40 ]; do typing; sleep 4; N=$((N+1)); done ) &
  TPID=$!
  prog_done
  # F: постійна памʼять стану — кеш оновлюється механічно, модель не робить розвідку
  state_fresh || state_rebuild
  ai_snapshot
  STATETXT=""
  if [ -s "$DIR/ai/state.md" ]; then
    STATETXT="
СТАН РОУТЕРА (кеш, АКТУАЛЬНИЙ — бот оновлює його сам після кожної зміни; НЕ витрачай ходи на перевірку цих параметрів CMD):
$(cat "$DIR/ai/state.md")"
  fi
  # --- G: ПАМʼЯТЬ ДІАЛОГУ БЕЗ ЧАСОВОГО ГЕЙТА (безперервна, файл обрізається за розміром) ---
  HIST=""
  if [ -s "$DIR/aihist" ]; then
    HIST="
Предыдущий диалог:
$(tail -n 14 "$DIR/aihist" | cut -c1-160)"
  fi
  # G: механічний журнал дій агента — "що я нещодавно робив" навіть тижневої давнини
  ACTL=""
  if [ -s "$DIR/ai/actions.log" ]; then
    ACTL="
ЩО ТИ НЕЩОДАВНО РОБИВ (твій журнал дій):
$(tail -n 8 "$DIR/ai/actions.log")"
  fi
  # C1: скіл за темою питання інʼєктується одразу — модель не витрачає хід на `cat skills/*`
  SKF=$(skill_pick "$Q"); SKILL_TXT=""
  # РАЦІОНАЛЬНІСТЬ ТОКЕНІВ: кеш греємо завжди (безкоштовно), а ТІЛО дока — лише для складних
  # задач; на прості питання модель отримує тільки вказівник і читає кеш сама, якщо треба.
  KBD_TOPIC=$(kb_pick "$Q"); KB_TXT=""
  if [ -n "$KBD_TOPIC" ]; then
    KBD=$(kb_fetch "$KBD_TOPIC")
    case "$Q" in
      *налашту*|*Налашту*|*зроби*|*Зроби*|*встанови*|*Встанови*|*чому*|*Чому*|*діагност*|*"не працює"*|*відвалю*|*пропада*|*настроить*|*Сделай*)
        [ -n "$KBD" ] && KB_TXT="
ПОГЛИБЛЕНІ ЗНАННЯ ПО ТЕМІ $KBD_TOPIC (джерело надійне):
$(printf '%s' "$KBD" | sed 's/[[:space:]]*$//')" ;;
      *)
        [ -n "$KBD" ] && KB_TXT="
Тема $KBD_TOPIC: коротко кажи з голови; глибокий довідник лежить у /etc/tg-bot/kbcache/$KBD_TOPIC.md — CMD: cat його ЛИШЕ якщо проста відповідь неможлива без деталей." ;;
    esac
  fi
  # уроки з минулого: локальні провали + спільний журнал GitHub (кеш 24год)
  LESSONS=""
  [ -s "$DIR/ai/mistakes.md" ] && LESSONS="$(tail -n 8 "$DIR/ai/mistakes.md")"
  LGH=$(lessons_fetch); [ -n "$LGH" ] && LESSONS="${LESSONS}
--- Спільні уроки (GitHub): ---
$LGH"
  LES_TXT=""
  [ -n "$LESSONS" ] && LES_TXT="
УРОКИ З МИНУЛОГО (твої реальні провали і вдалі рецепти) — НЕ повторюй помилкові команди, перевіряй підхід:
$LESSONS"
  if [ -n "$SKF" ] && [ -s "$SKF" ]; then
    SKILL_TXT="
ЗНАННЯ ПО ТЕМІ ВЖЕ НАДАНО (джерело: $SKF) — НЕ витрачай хід на CMD: cat цього файлу, знання повні:
$(cat "$SKF")"
    alog INTENT "skill=$(basename "$SKF")"
  fi
  SYS1="$(ai_rules_full)$SKILL_TXT$KB_TXT$LES_TXT$STATETXT
Состояние роутера сейчас (динамика — uptime/RAM/load/сеть): $SNAP
Устройства онлайн: ${DEVS:-нет}$ACTL$HIST"
  # C3: легке ядро для продовжень — без повного core.txt/recipes (економія ~1000 ток/хід)
  CONT_CORE="$(EMERGENCY_CORE)
ПРАВИЛО UCI: будь-яка зміна = uci set ... && uci commit <конфіг>; повідомляй успіх лише після перевірки значення зворотною командою."
  [ -s "$DIR/ai/corrections.md" ] && CONT_CORE="$CONT_CORE
КОРЕКЦІЇ ВЛАСНИКА:
$(tail -c 600 "$DIR/ai/corrections.md")"
  SYSN="$(printf '%s' "$CONT_CORE")$HIST
Вопрос пользователя: $Q
(Продовжуй діалог; історія та журнал дій вище.)"
  CUR="$Q"
  CHFAIL=""
  STEP=0
  FSAY=""
  TASKLOG=""
  # складна задача (налаштуй/зроби/встанови) = більший бюджет ходів
  MAXSTEP=5
  case "$Q" in
    *налашту*|*Налашту*|*зроби*|*Зроби*|*встанови*|*Встанови*|*настроить*|*Настроить*|*сделай*|*Сделай*|*установи*|*Установи*|*розблоку*|*Розблоку*) MAXSTEP=10 ;;
  esac
  while [ $STEP -lt $MAXSTEP ]; do
    STEP=$((STEP+1))
    if [ "$STEP" = "1" ]; then
      ai_call "$SYS1" "$CUR" 700
    else
      # C4: продовження — коротший бюджет (проміжний SAY ≤40 симв.)
      CUR="РЕЗУЛЬТАТ КОМАНДЫ '$PCMD':
$(trim_out "${OUT:-}" 1000)"
      ai_call "$SYSN" "$CUR" 500
    fi
    [ -z "$ANS" ] && { alog ERR "step$STEP порожня відповідь; lasterr: $(head -c 140 "$DIR/lasterr" 2>/dev/null)"; CHFAIL=1; break; }
    ANS=$(printf '%s' "$ANS" | sed -e 's/^[[:space:]]*<SAY:/SAY:/' -e 's/^[[:space:]]*<CMD:/CMD:/' -e 's/<SAY>//g' -e 's/<\/SAY>//g' -e 's/<CMD>//g' -e 's/<\/CMD>//g' -e 's/>[[:space:]]*$//')
    # Модель інколи відповідає JSON-обʼєктом замість протоколу — конвертуємо
    case "$ANS" in
      \{*\"CMD\"*|*\{\"action\"*|*\"CMD\":*)
        JC=$(printf '%s' "$ANS" | jsonfilter -e '$.CMD' -e '$.cmd' 2>/dev/null | head -1)
        JS=$(printf '%s' "$ANS" | jsonfilter -e '$.SAY' -e '$.say' 2>/dev/null | head -1)
        [ -n "$JC$JS" ] && ANS="CMD: ${JC:--}
SAY: $JS"
        ;;
    esac
    # хвіст «... CMD: -» вклеєний в SAY — розрізаємо до парсингу
    ANS=$(unglue_cmd "$ANS")
    # C1-мульти: збираємо УСІ команди ходу (CMD:, CMD2:, …) + розрізаємо легаси ";-ланцюжки"
    ALLCMDS=$(printf '%s' "$ANS" | sed -n 's/^CMD[0-9]*:[[:space:]]*//p' | sed '/^[[:space:]]*$/d' \
      | while IFS= read -r CL; do semi_split "$CL"; done \
      | sed '/^[[:space:]]*$/d' | head -4)
    NCMD=$(printf '%s\n' "$ALLCMDS" | grep -c '^')
    PCMD=$(printf '%s' "$ALLCMDS" | head -1)
    # D: план задачі — прозорість без зайвого ходу
    PLANL=$(printf '%s' "$ANS" | sed -n 's/^PLAN:[[:space:]]*//p' | head -c 300)
    [ -n "$PLANL" ] && send_mk "<b>📋 $(printf '%s' "$(t plan_lbl)" | sed 's/📋 //')</b>
$(esc "$PLANL")"
    FSAY=$(printf '%s' "$ANS" | sed -n 's/^SAY:[[:space:]]*//p' | head -1)
    if [ -z "$FSAY" ] && [ -z "$PCMD" ]; then
      FSAY=$(printf '%s' "$ANS" | sed '/./,$!d' | head -c 600)
    elif [ -z "$FSAY" ]; then
      FSAY=$(printf '%s' "$ANS" | grep -v '^CMD:' | tr '\n' ' ' | head -c 600)
    fi
    PSTRIP=$(printf '%s' "$PCMD" | tr -d ' \t\r\n')
    alog STEP "step$STEP CMD=[$NCMD:${PCMD:-—}] SAYLEN=${#FSAY} raw:$(printf '%s' "$ANS" | tr '\n\t' '  ' | head -c 240)"
    case "$PSTRIP" in
      ""|"-"|"--"|"->"|"→"|"—") break ;;
      *"–"*|*"—"*) break ;;
    esac
    # C1: БАТЧ читання — кілька read-only команд за один хід (мутації заборонені)
    if [ "$NCMD" -gt 1 ]; then
      BLIST="$DIR/.batch.$$"
      printf '%s\n' "$ALLCMDS" > "$BLIST"
      BRES=""
      BMUT=""
      while IFS= read -r BC; do
        [ -z "$BC" ] && continue
        case "$(printf '%s' "$BC" | tr -d ' \t')" in "-"|"--") continue ;; esac
        BC=$(printf '%s' "$BC" | sed 's/<[^>]*>//g; s/&lt;/</g; s/&gt;/>/g; s/&amp;/\&/g' | sed 's/^[[:space:]`]*//; s/[[:space:]`]*$//')
        BC=$(uci_autocommit "$BC")
        if ! sanitize_cmd "$BC"; then
          rm -f "$BLIST"; kill "$TPID" 2>/dev/null; prog_done
          alog ERR "batch sanitize REJECT: $(printf '%s' "$BC" | head -c 140)"
          reply "$(t san_rej)"
          return
        fi
        if is_mut "$BC"; then BMUT="$BC"; break; fi
        ai_run "$BC"
        act_log "$BC" "${RC:-?}"
        BRES="$BRES
── $BC:
$(trim_out "$OUT" 500)"
        TASKLOG="$TASKLOG
• <code>$(printf '%s' "$BC" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' | head -c 110)</code> → <i>$(printf '%s' "$OUT" | tr '\n\t' '  ' | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' | head -c 90)</i>"
      done < "$BLIST"
      rm -f "$BLIST"
      if [ -n "$BMUT" ]; then
        kill "$TPID" 2>/dev/null; prog_done
        alog CONF "batch з мутацією відхилено: $(printf '%s' "$BMUT" | head -c 120)"
        reply "$(t batch_mut)"
        return
      fi
      CUR="РЕЗУЛЬТАТ КОМАНД (у порядку виконання):$BRES"
      continue
    fi
    PCMD=$(printf '%s' "$PCMD" | sed 's/^->//; s/^→//')
    # Модель інколи загортає команду в HTML — зрізаємо теги і розкодуємо entities
    PCMD=$(printf '%s' "$PCMD" | sed 's/<[^>]*>//g; s/&lt;/</g; s/&gt;/>/g; s/&amp;/\&/g' | sed 's/^[[:space:]`]*//; s/[[:space:]`]*$//')
    PCMD=$(uci_autocommit "$PCMD")
    # C5: захист у глибину — підстановки/; /&/спуф-юнікод у CMD недопустимі
    if ! sanitize_cmd "$PCMD"; then
      kill "$TPID" 2>/dev/null; prog_done
      alog ERR "sanitize REJECT: $(printf '%s' "$PCMD" | tr '\n\t' '  ' | head -c 160)"
      reply "$(t san_rej)"
      return
    fi
    if is_mut "$PCMD"; then
      kill "$TPID" 2>/dev/null; prog_done
      # Дедуп: ту саму команду щойно підтверджено й виконано?
      if [ -f "$DIR/.lastconf" ]; then
        LC=$(sed -n '1p' "$DIR/.lastconf"); LT=$(sed -n '2p' "$DIR/.lastconf")
        case "$Q" in *[Пп]овтор*|*[Rr]epeat*) ;; *)
          if [ "$PCMD" = "$LC" ] && [ $(( $(date +%s) - ${LT:-0} )) -le 300 ]; then
            reply "✅ Цю команду вже виконано <5 хв тому — результат вище в чаті. Щоб повторити примусово, додайте слово «повтор»."
            return
          fi ;;
        esac
      fi
      printf '%s' "$PCMD" > "$DIR/aipend"
      date +%s > "$DIR/.apts"
      alog PEND "очікує підтвердження: $PCMD"
      RISK=""
      case "$PCMD" in
        *commit*network*|*"network reload"*|*"network restart"*|*commit*wireless*|*"wifi reload"*|*commit*firewall*)
          RBACKUP=$(risk_backup); RISK="
↩️ Якщо втратите доступ: /rollback ($RBACKUP) або кнопка 🔒" ;;
      esac
      DIFF=$(uci changes 2>/dev/null | head -c 300)
      [ -n "$DIFF" ] && RISK="$RISK
📋 Незастосовані зміни зараз:
$(esc "$DIFF")"
      reply "$(printf "$(t ai_confirm)" "$(esc "$PCMD")")"
      case "$RISK" in *"🔒"*) CONFMK="$AI_CONF2_MARKUP" ;; *) CONFMK="$AI_CONF_MARKUP" ;; esac
      send_mk "$(t ai_conflbl)$RISK" "$CONFMK"
      return
    fi
    prog_msg "$(printf "$(t cmd_run)" "$(esc "$PCMD")")"
    ai_run "$PCMD"
    act_log "$PCMD" "${RC:-?}"
    alog OUT "→ $(printf '%s' "$OUT" | tr '\n\t' '  ' | head -c 200)"
    # незнищенний слід для власника: що робили і що вийшло (навіть якщо модель помре серед задачі)
    TASKLOG="$TASKLOG
• <code>$(printf '%s' "$PCMD" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' | head -c 110)</code> → <i>$(printf '%s' "$OUT" | tr '\n\t' '  ' | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' | head -c 90)</i>"
  done
  kill "$TPID" 2>/dev/null
  prog_done
  if [ -n "$TASKLOG" ] && [ "$STEP" -ge "$MAXSTEP" ]; then
    FSAY="${FSAY:-}
<b>⚠️ Ліміт ходів — журнал задачі (що встиг зробити):</b>$TASKLOG
Скажіть «продовжуй» і я продовжу з цього місця."
  elif [ -n "$TASKLOG" ]; then
    FSAY="$FSAY
<b>Журнал задачі:</b>$TASKLOG"
  fi
  if [ -n "$CHFAIL" ]; then
    FSAY="$(t ai_chainfail)"
  elif [ -z "$FSAY" ]; then
    FSAY="$(t ai_noans)"
  fi
  FSAY=$(printf '%s' "$FSAY" | awk '
    /<system-reminder>/ {inf=1; next}
    inf && /<\/system-reminder>/ {inf=0; next}
    inf {next}
    /^[[:space:]]*$/ {if (!bl) print ""; bl=1; next}
    {bl=0; print}
  ' | sed '/./,$!d; ${/^$/d}')
  FSAY=$(mask_secrets "$FSAY")
  FSAY=$(printf '%s' "$FSAY" | awk '
    /<system-reminder>/ {inf=1; next}
    inf && /<\/system-reminder>/ {inf=0; next}
    inf {next}
    /^[[:space:]]*$/ {if (!bl) print ""; bl=1; next}
    {bl=0; print}
  ' | sed '/./,$!d; ${/^$/d}')
  reply_rich "🤖 $FSAY"
  if [ -z "$CHFAIL" ]; then
    { printf 'Пользователь: %.120s\nАссистент: %.200s\n' "$Q" "$FSAY"; } >> "$DIR/aihist"
    tail -c 3072 "$DIR/aihist" > "$DIR/aihist.t" 2>/dev/null && mv "$DIR/aihist.t" "$DIR/aihist"
  fi
}

cmd_scan() {
  # Скан УСІХ радіо (2.4 + 5 ГГц): iwinfo дає список інтерфейсів — обходимо кожне
  IFACES=$(iwinfo 2>/dev/null | awk '{print $1}')
  [ -z "$IFACES" ] && { reply "$(t sc_nosup)"; return; }
  reply "$(printf "$(t sc_doing)" "$(printf '%s' "$IFACES" | tr '\n' '+')")"
  RAW=""
  for IF in $IFACES; do
    R=$(iwinfo "$IF" scan 2>/dev/null)
    [ -n "$R" ] && RAW="$RAW
$R"
  done
  RAW=$(printf '%s' "$RAW" | sed '/^$/d')
  [ -z "$RAW" ] && { reply "$(t sc_empty)"; return; }

  T=/tmp/tg-scan.$$
  printf '%s\n' "$RAW" | awk '
    /^Cell / {
      if (essid != "") printf "%s|%s|%s\n", ch, sig, essid;
      essid=""; ch=""; sig=""
    }
    /Frequency:/ {
      for (i=1;i<=NF;i++) if ($i=="Channel:") ch=$(i+1)
    }
    /Signal:/ {
      for (i=1;i<=NF;i++) if ($i=="Signal:") sig=$(i+1)
    }
    /ESSID:/ {
      e=$0; sub(/.*ESSID: */,"",e); gsub(/^"|"$/,"",e);
      if (e=="") e="(скрытая)";
      essid=e
    }
    END {
      if (essid != "") printf "%s|%s|%s\n", ch, sig, essid
    }' | sort -t'|' -k1,1n -k2,2rn > "$T"

  C24=$(awk -F'|' '$1<=13 && $1!="" {c[$1]++} END{for(i in c) print i":"c[i]}' "$T" | sort -t: -k1,1n | tr '\n' ' ')
  # 5 ГГц: окрема статистика зайнятості (канали >13)
  C5=$(awk -F'|' '$1>13 {c[$1]++} END{for(i in c) print i":"c[i]}' "$T" | sort -t: -k1,1n | tr '\n' ' ')
  # Рекомендація каналу: сила сусідів + ПЕРЕКРИТТЯ ДІАПАЗОНІВ (сусідній канал теж заважає:
  # 20МГц канал заливає ±2 сусіди повністю, ±4 — краями). Вага: >=-60:4, -61..-70:3, -71..-80:2, слабші:1
  OWN=$(uci show wireless 2>/dev/null | grep "\.ssid=" | sed "s/.*ssid='//; s/'$//" | tr '\n' '|')
  SCORES=$(awk -F'|' -v own="|$OWN" -v cands="1 6 11 36 40 44 48" '
    BEGIN { nc = split(cands, CA, " ") }
    $3 != "" {
      e="|" $3 "|"
      if (index(own, e)) next
      sig=$2+0; w=1
      if (sig>=-60) w=4; else if (sig>=-70) w=3; else if (sig>=-80) w=2
      chn=$1+0
      for (k=1; k<=nc; k++) {
        c=CA[k]; d=c-chn; if (d<0) d=-d
        if (d==0) s[c]+=w
        else if (d<=2) s[c]+=w*0.5
        else if (d<=4 && c<=13) s[c]+=w*0.2
      }
    }
    END { for (c in s) printf "%s:%d\n", c, s[c] }' "$T")
  BEST=""
  MIN=999999
  for CAND in 1 6 11; do
    S=$(printf '%s\n' "$SCORES" | grep "^$CAND:" | cut -d: -f2)
    S=${S:-0}
    if [ "$S" -lt "$MIN" ]; then MIN=$S; BEST=$CAND; fi
  done
  # наші поточні канали: якщо кандидат = свій канал — порада «переїзд не потрібен»
  OWNCH24=""; OWNCH5=""
  i=0
  while :; do
    WD=$(uci -q get wireless.@wifi-iface[$i].device 2>/dev/null) || break
    WCH=$(uci -q get wireless.$WD.channel 2>/dev/null)
    case "$WCH" in ''|*[!0-9]*) i=$((i+1)); continue ;; esac
    if [ "$WCH" -gt 13 ]; then OWNCH5="$WCH"; else OWNCH24="$WCH"; fi
    i=$((i+1))
  done
  # бали нашого поточного каналу — для гістерезису (не пинг-понгити при малій різниці)
  SC24_OWN=$(printf '%s\n' "$SCORES" | grep "^$OWNCH24:" | cut -d: -f2); SC24_OWN=${SC24_OWN:-0}
  SC5_OWN=$(printf '%s\n' "$SCORES" | grep "^$OWNCH5:" | cut -d: -f2); SC5_OWN=${SC5_OWN:-0}

  # Окремі таблиці 2.4 / 5 ГГц, найсильніші зверху; rich_message вміщує ~30000 симв —
  # показуємо ВСІ мережі (cap 120 на діапазон). awk ІНЛАЙН: через змінну ламається екранування!
  ROWS24=$(awk -F'|' '$1<=13 && $1!=""' "$T" | sort -t'|' -k2,2rn | head -120 | awk -F'|' '$3!="" {
    e=substr($3,1,28); gsub(/&/,"\\&amp;",e); gsub(/</,"\\&lt;",e); gsub(/>/,"\\&gt;",e)
    printf "<tr><td>%s dBm</td><td align=\"center\">ch%s</td><td>%s</td></tr>", $2, $1, e
  }')
  ROWS5=$(awk -F'|' '$1>13' "$T" | sort -t'|' -k2,2rn | head -120 | awk -F'|' '$3!="" {
    e=substr($3,1,28); gsub(/&/,"\\&amp;",e); gsub(/</,"\\&lt;",e); gsub(/>/,"\\&gt;",e)
    printf "<tr><td>%s dBm</td><td align=\"center\">ch%s</td><td>%s</td></tr>", $2, $1, e
  }')
  NALL=$(wc -l < "$T")
  # Порада і для 5 ГГц: найменш завантажений серед не-DFS каналів (ваги ті самі)
  BEST5=""
  MIN5=999999
  for CAND in 36 40 44 48; do
    S=$(printf '%s\n' "$SCORES" | grep "^$CAND:" | cut -d: -f2)
    S=${S:-0}
    if [ "$S" -lt "$MIN5" ]; then MIN5=$S; BEST5=$CAND; fi
  done
  MSG="<h3>$(t sc_hdr)</h3>

<h4>$(t sc_b24)</h4>
<p>$(t sc_busy)</p>
<code>$C24</code>
${ROWS24:+<table bordered striped><tr><th>$(t th_sig)</th><th>$(t th_ch)</th><th>$(t th_ssid)</th></tr>$ROWS24</table>}
<p>$(if [ "$BEST" = "$OWNCH24" ]; then printf "$(t sc_keep)" "$BEST"; elif [ -n "$OWNCH24" ] && [ "${SC24_OWN:-999}" -le "$MIN" ]; then printf "$(t sc_keep)" "$OWNCH24"; elif [ -n "$OWNCH24" ] && [ "${SC24_OWN:-999}" -le $((MIN+3)) ]; then printf "$(t sc_stay)" "$BEST"; else printf "$(t sc_adv)" "$BEST"; fi)</p>
${C5:+<h4>$(t sc_b5)</h4>
<p>$(t sc_busy5)</p>
<code>$C5</code>
${ROWS5:+<table bordered striped><tr><th>$(t th_sig)</th><th>$(t th_ch)</th><th>$(t th_ssid)</th></tr>$ROWS5</table>}
<p>$(if [ "$BEST5" = "$OWNCH5" ]; then printf "$(t sc_keep)" "$BEST5"; elif [ -n "$OWNCH5" ] && [ "${SC5_OWN:-999}" -le "$MIN5" ]; then printf "$(t sc_keep)" "$OWNCH5"; elif [ -n "$OWNCH5" ] && [ "${SC5_OWN:-999}" -le $((MIN5+1)) ]; then printf "$(t sc_stay)" "$BEST5"; else printf "$(t sc_adv5)" "$BEST5"; fi)</p>}
<p>$(printf "$(t sc_total)" "$NALL")</p>"
  # страховка: rich_message ~30000 симв — ріжемо тільки якщо зовсім великий ефір
  if [ ${#MSG} -gt 28000 ]; then
    ROWS24=$(awk -F'|' '$1<=13 && $1!=""' "$T" | sort -t'|' -k2,2rn | head -60 | awk -F'|' '$3!="" {
      e=substr($3,1,28); gsub(/&/,"\\&amp;",e); gsub(/</,"\\&lt;",e); gsub(/>/,"\\&gt;",e)
      printf "<tr><td>%s dBm</td><td align=\"center\">ch%s</td><td>%s</td></tr>", $2, $1, e
    }')
    ROWS5=$(awk -F'|' '$1>13' "$T" | sort -t'|' -k2,2rn | head -60 | awk -F'|' '$3!="" {
      e=substr($3,1,28); gsub(/&/,"\\&amp;",e); gsub(/</,"\\&lt;",e); gsub(/>/,"\\&gt;",e)
      printf "<tr><td>%s dBm</td><td align=\"center\">ch%s</td><td>%s</td></tr>", $2, $1, e
    }')
    MSG="<h3>$(t sc_hdr)</h3>

<h4>$(t sc_b24)</h4>
<p>$(t sc_busy)</p>
<code>$C24</code>
${ROWS24:+<table bordered striped><tr><th>$(t th_sig)</th><th>$(t th_ch)</th><th>$(t th_ssid)</th></tr>$ROWS24</table>}
<p>$(if [ "$BEST" = "$OWNCH24" ]; then printf "$(t sc_keep)" "$BEST"; elif [ -n "$OWNCH24" ] && [ "${SC24_OWN:-999}" -le "$MIN" ]; then printf "$(t sc_keep)" "$OWNCH24"; elif [ -n "$OWNCH24" ] && [ "${SC24_OWN:-999}" -le $((MIN+3)) ]; then printf "$(t sc_stay)" "$BEST"; else printf "$(t sc_adv)" "$BEST"; fi)</p>
${C5:+<h4>$(t sc_b5)</h4>
<p>$(t sc_busy5)</p>
<code>$C5</code>
${ROWS5:+<table bordered striped><tr><th>$(t th_sig)</th><th>$(t th_ch)</th><th>$(t th_ssid)</th></tr>$ROWS5</table>}
<p>$(if [ "$BEST5" = "$OWNCH5" ]; then printf "$(t sc_keep)" "$BEST5"; elif [ -n "$OWNCH5" ] && [ "${SC5_OWN:-999}" -le "$MIN5" ]; then printf "$(t sc_keep)" "$OWNCH5"; elif [ -n "$OWNCH5" ] && [ "${SC5_OWN:-999}" -le $((MIN5+1)) ]; then printf "$(t sc_stay)" "$BEST5"; else printf "$(t sc_adv5)" "$BEST5"; fi)</p>}
<p>$(printf "$(t sc_total)" "$NALL")</p>"
  fi
  send_rich "$MSG" || reply "$MSG"
  rm -f "$T"
}

# --- периодические проверки (раз в минуту) ---
do_checks() {
  # --- присутствие людей ---
  PCFG="$DIR/presence.cfg"
  PST="$DIR/presence.state"
  if [ -s "$PCFG" ]; then
    touch "$PST"
    ARP_MACS=$(awk '$3=="0x2"{print tolower($4)}' /proc/net/arp)
    while IFS='|' read -r MC NM; do
      [ -z "$MC" ] && continue
      HERE=0
      echo "$ARP_MACS" | grep -qxF "$(printf '%s' "$MC" | tr 'A-F' 'a-f')" && HERE=1
      if [ "$HERE" != "1" ]; then
        LIP=$(awk -v m="$(printf '%s' "$MC" | tr 'A-F' 'a-f')" 'tolower($2)==m {print $3}' /tmp/dhcp.leases 2>/dev/null | head -1)
        [ -n "$LIP" ] && ping -c1 -W1 "$LIP" >/dev/null 2>&1 && HERE=1
      fi
      PREV=""
      [ -f "$PST" ] && PREV=$(grep "^$MC|" "$PST" | cut -d'|' -f2)
      if [ "$PREV" != "$HERE" ]; then
        grep -v "^$MC|" "$PST" 2>/dev/null > "$PST.new"
        echo "$MC|$HERE" >> "$PST.new"
        mv "$PST.new" "$PST"
        TM=$(date '+%H:%M')
        ENM=$(esc "$NM")
        if [ "$HERE" = "1" ]; then
          reply "$(printf "$(t p_home)" "$ENM" "$TM")"
        else
          reply "$(printf "$(t p_away)" "$ENM" "$TM")"
        fi
      fi
    done < "$PCFG"
  fi

  # --- мониторинг хостов ---
  MCFG="$DIR/mon.cfg"
  if [ -s "$MCFG" ]; then
    NEW=""
    while IFS='|' read -r H LB ST; do
      [ -z "$H" ] && continue
      ping -c1 -W2 "$H" >/dev/null 2>&1 && UP=1 || UP=0
      if [ "$ST" != "$UP" ] && [ "$ST" != "?" ]; then
        ELB=$(esc "$LB")
        if [ "$UP" = "1" ]; then
          reply "$(printf "$(t h_up)" "$ELB" "$H" "$(date '+%H:%M')")"
        else
          reply "$(printf "$(t h_down)" "$ELB" "$H" "$(date '+%H:%M')")"
        fi
      fi
      echo "$H|$LB|$UP" >> "${MCFG}.new"
    done < "$MCFG"
    [ -f "${MCFG}.new" ] && mv "${MCFG}.new" "$MCFG"
  fi
}

# --- обработка апдейтов ---
process_updates() {
  OFFSET=0
  [ -f "$DIR/offset" ] && OFFSET=$(cat "$DIR/offset")

  UPDATES=$(curl -s --max-time $((LONGPOLL+15)) "$API/getUpdates?timeout=$LONGPOLL&offset=$OFFSET&allowed_updates=%5B%22message%22,%22callback_query%22%5D")
  [ -z "$UPDATES" ] && sleep 5 && return

  TOTAL=$(jsonfilter -s "$UPDATES" -e '$.result[*].update_id' 2>/dev/null | wc -l)
  case "$TOTAL" in
    ''|*[!0-9]*)
      alog ERR "process_updates: jsonfilter зламався на бачі апдейтів ($(printf '%s' "$UPDATES" | head -c 100))"
      return
      ;;
  esac
  [ "$TOTAL" -gt 0 ] && { alog POLL "отримано $TOTAL апдейтів (offset=$OFFSET)"; touch "$DIR/.dms_ack" 2>/dev/null; }

  i=0
  LAST=""
  while [ "$i" -lt "$TOTAL" ]; do
    UID_=$(jsonfilter -s "$UPDATES" -e "\$.result[$i].update_id" 2>/dev/null)
    LAST="$UID_"

    CID=$(jsonfilter -s "$UPDATES" -e "\$.result[$i].message.chat.id" 2>/dev/null)
    TXT=$(jsonfilter -s "$UPDATES" -e "\$.result[$i].message.text" 2>/dev/null)

    if [ "$CID" = "$CHAT" ]; then
      if [ -n "$TXT" ]; then
        # --- контекст вводу текстом (.mact): не-командне повідомлення споживається
        # відкладеною дією меню (ввід SSID/пароля/цілі ping тощо); команди / проходять ---
        case "$TXT" in
          "/"*) ;;
          *)
            MIN=$(mact_get "$TXT")
            if [ -n "$MIN" ]; then
              rm -f "$DIR/.mact"
              MA_A="${MIN%%|*}"; MA_V="${MIN#*|}"
              case "$MA_A" in
                wfk:*|wfs:*|wfc:*)
                  IDX="${MA_A#*:}"
                  D=$(uci -q get wireless.@wifi-iface[$IDX].device 2>/dev/null)
                  if [ -z "$D" ]; then
                    reply "$(t wf_none)"
                  elif ! wf_safe "$MA_V"; then
                    mact_set "$MA_A"
                    case "$MA_A" in wfk:*) reply "$(t wf_bad_key)" ;; wfs:*) reply "$(t wf_bad_ssid)" ;; *) reply "$(t wf_bad_ch)" ;; esac
                  else
                    case "$MA_A" in
                      wfk:*)
                        L=${#MA_V}
                        if [ "$L" -ge 8 ] && [ "$L" -le 63 ]; then
                          wf_apply "uci set wireless.@wifi-iface[$IDX].key='$MA_V'"
                        else
                          mact_set "$MA_A"; reply "$(t wf_bad_key)"
                        fi ;;
                      wfs:*)
                        L=${#MA_V}
                        if [ "$L" -ge 1 ] && [ "$L" -le 32 ]; then
                          wf_apply "uci set wireless.@wifi-iface[$IDX].ssid='$MA_V'"
                        else
                          mact_set "$MA_A"; reply "$(t wf_bad_ssid)"
                        fi ;;
                      wfc:*)
                        case "$MA_V" in auto|[0-9]*)
                          wf_apply "uci set wireless.$D.channel='$MA_V'" ;;
                          *) mact_set "$MA_A"; reply "$(t wf_bad_ch)" ;;
                        esac ;;
                    esac
                  fi
                  i=$((i+1)); continue ;;
                fwa_e:*|fwa_i:*|fwa_p:*)
                  PR="${MA_A#fwa_}"; STEP="${PR%%:*}"; REST="${PR#*:}"
                  # REST: e-крок="" | i-крок="proto" | p-крок="proto:eport"
                  case "$STEP" in
                    e)
                      if ok_port "$MA_V"; then
                        mact_set "fwa_i:$REST:$MA_V"; reply "$(t fw_ask_dip)"
                      else
                        mact_set "$MA_A"; reply "$(t fw_bad_eport)"
                      fi ;;
                    i)
                      if ok_ip "$MA_V"; then
                        mact_set "fwa_p:$REST:$MA_V"; reply "$(t fw_ask_dport)"
                      else
                        mact_set "$MA_A"; reply "$(t fw_bad_dip)"
                      fi ;;
                    p)
                      PROTO="${REST%%:*}"
                      TMPR="${REST#*:}"
                      EPORT="${TMPR%%:*}"
                      DIP="${TMPR##*:}"
                      if [ "$MA_V" != "-" ] && ! ok_port "$MA_V"; then
                        mact_set "$MA_A"; reply "$(t fw_bad_eport)"; i=$((i+1)); continue
                      fi
                      case "$PROTO" in tcp|udp) PP="$PROTO" ;; *) PP="tcp udp" ;; esac
                      CMDL="uci add firewall redirect && uci set firewall.@redirect[-1].name='tgbot_$EPORT' && uci set firewall.@redirect[-1].proto='$PP' && uci set firewall.@redirect[-1].src='wan' && uci set firewall.@redirect[-1].src_dport='$EPORT' && uci set firewall.@redirect[-1].dest_ip='$DIP'"
                      [ "$MA_V" != "-" ] && CMDL="$CMDL && uci set firewall.@redirect[-1].dest_port='$MA_V'"
                  fw_confirm "$CMDL && uci commit firewall && /etc/init.d/firewall restart"
                      ;;
                esac
                i=$((i+1)); continue ;;
                dg:*)
                  case "$MA_V" in *[!A-Za-z0-9.-]*|'') mact_set "$MA_A"; reply "$(t dg_bad)"; i=$((i+1)); continue ;; esac
                  case "${MA_A#dg:}" in
                    ping)  DGCMD="ping -c 4 $MA_V" ; DGNAME="ping" ;;
                    trace) DGCMD="traceroute -m 15 -w 2 $MA_V 2>&1" ; DGNAME="traceroute" ;;
                    ns)    DGCMD="nslookup $MA_V" ; DGNAME="nslookup" ;;
                    *) i=$((i+1)); continue ;;
                  esac
                  printf '%s' "$DGCMD" > "$DIR/.lb_cmd"
                  echo "$MSGID_CB" > "$DIR/.lb_msg"
                  : > "$DIR/.lb_out"; rm -f "$DIR/.lb_done"
                  reply "$(printf "$(t dg_doing)" "$DGNAME" "$(esc "$MA_V")")"
                  ( OUT=$(ai_run "$DGCMD"); printf '%s' "$OUT" > "$DIR/.lb_out"; touch "$DIR/.lb_done" ) &
                  i=$((i+1)); continue ;;
                pkg:q)
                  case "$MA_V" in *[!a-zA-Z0-9._-]*|"") mact_set "pkg:q"; reply "$(t pk_bad)"; i=$((i+1)); continue ;; esac
                  PINST=$(apk info -e "$MA_V" 2>/dev/null && echo ✅встановлено || echo ❌не знайдено)
                  PINFO=$(timeout 15 apk search -e "$MA_V" 2>/dev/null | head -3)
                  PK_KB="{\"inline_keyboard\":[[{\"text\":\"➕ apk add\",\"callback_data\":\"pki:$MA_V\"},{\"text\":\"➖ apk del\",\"callback_data\":\"pkr:$MA_V\"}],[{\"text\":\"$(t mnback)\",\"callback_data\":\"mnu:sys\"}]]}"
                  send_mk "📦 <b>$(esc "$MA_V")</b>: $PINST
${PINFO:+<code>$(esc "$PINFO")</code>}" "$PK_KB"
                  i=$((i+1)); continue ;;
                sshk:a)
                  case "$MA_V" in
                    ssh-ed25519\ *|ssh-rsa\ *|ecdsa-sha2-nistp*\ *)
                      if ! wf_safe "$MA_V"; then reply "$(t ssh_bad)"; i=$((i+1)); continue; fi
                      K64=$(printf '%s' "$MA_V" | awk '{print $2}')
                      case "$K64" in *[!A-Za-z0-9+/=]*|"") reply "$(t ssh_bad)"; i=$((i+1)); continue ;; esac
                      fw_confirm "echo '$MA_V' >> /etc/dropbear/authorized_keys" ;;
                    *) reply "$(t ssh_bad)" ;;
                  esac
                  i=$((i+1)); continue ;;
                pbr_add)
                  if ! parse_ip_cidr "$MA_V"; then
                    mact_set "pbr_add"
                    reply "$(t pbr_add_bad)"
                  else
                    echo "$MA_V" >> "$DIR/blocked.list"
                    reply "$(printf "$(t pbr_add_ok)" "$MA_V")"
                  fi ;;
                *) : ;;
              esac
            fi
            ;;
        esac
        case "$TXT" in
          "/start"|"/menu")
            send_menu "$(menu_text)"
            ;;
          "/help")
            send_menu "$(help_text)"
            ;;
          "/status")
            OUTS="$(status_text)"
            send_rich "$OUTS" || reply "$OUTS"
            ;;
          "/devices")
            OUTD="$(devices_text)"
            send_rich "$OUTD" || reply "$OUTD"
            KB=$(devices_kb) && send_mk "🏷 Швидкі дії — тапні щоб зробити IP статичним:" "$KB"
            ;;
          "/wan")
            reply "$(t wan_run)"
            ifup wan 2>/dev/null
            ;;
          "/backup")
            cmd_backup
            ;;
          "/qr")
            cmd_qr
            ;;
          "/scan")
            cmd_scan
            ;;
          "/wifi")
            KB=$(wf_kb) && send_mk "$(t wf_pick)" "$KB" || reply "$(t wf_none)"
            ;;
          "/cancel")
            rm -f "$DIR/aipend" "$DIR/.mact" "$DIR/.lb_cmd" "$DIR/.lb_msg" "$DIR/.lb_out" "$DIR/.lb_done" "$DIR/.pmid" "$DIR/rbarm" "$DIR/rbkarm"
            reply "$(t cancel_ok)"
            ;;
          "/usage")
            if [ -s "$DIR/toklog" ]; then
              TODAY=$(date +%s)
              OUTU=$(awk -F'|' -v today=$((TODAY-86400)) '$1>=today {c[$2]++; p[$2]+=$3; k[$2]+=$4} END {for (m in c) printf "• %s — %d викликів | вхідні: %d | вихідні: %d\n", m, c[m], p[m], k[m]}' "$DIR/toklog")
              [ -n "$OUTU" ] && reply_rich "<b>📈 Витрати AI за 24 год</b>
$OUTU" || reply "$(t usage_none)"
            else
              reply "$(t usage_none)"
            fi
            ;;
          "/ai"*|"/ai")
            touch "$DIR/aimode"
            ai_agent "${TXT#/ai}"
            ;;
          "/ailog")
            if [ -s "$DIR/ailog" ]; then
              reply_doc "$DIR/ailog" "🧾 AI-лог (останні події)"
            else
              reply "🧾 Лог порожній"
            fi
            ;;
          "/rollback")
            L=$(ls -d "$DIR/rb/"* 2>/dev/null | tail -n 1)
            if [ -z "$L" ]; then
              reply "↩️ Знімків ще немає — відкатувати не з чого"
            else
              for CC in network wireless dhcp firewall system sqm; do
                [ -f "$L/$CC" ] && cp "$L/$CC" "/etc/config/$CC"
              done
              /etc/init.d/network reload 2>/dev/null
              /etc/init.d/dnsmasq restart 2>/dev/null
              /etc/init.d/firewall restart 2>/dev/null
              alog CONF "rollback -> $L"
              reply "↩️ Конфіги відкотто до знімка $(basename "$L")"
            fi
            ;;
          "/topo"*|"/topo")
            ARGS=$(printf '%s' "${TXT#/topo}" | sed 's/^[[:space:]]*//')
            if [ -z "$ARGS" ]; then
              TOPOC=$(tail -c 400 "$DIR/ai/topology.md" 2>/dev/null)
              reply "🧭 Топологія:${TOPOC:+
$TOPOC}${TOPOC:-порожня}. Додати: /topo 192.168.1.50 NAS"
            else
              echo "$(date '+%m.%d') $ARGS" >> "$DIR/ai/topology.md"
              alog CONF "topology: $ARGS"
              reply "🧭 Запамʼятав: $ARGS"
            fi
            ;;
          "/model"*|"/model")
            CURM=$(uci -q get tgbot.config.ai_model); [ -z "$CURM" ] && CURM="qwen/qwen3.6-27b"
            ALTM=$(uci -q get tgbot.config.ai_model_alt); [ -z "$ALTM" ] && ALTM="nvidia/nemotron-3-super-120b-a12b:free"
            GRC=$(uci -q get tgbot.config.ai_groq_chain); [ -z "$GRC" ] && GRC="qwen/qwen3.6-27b openai/gpt-oss-120b"
            MDL_KB="{\"inline_keyboard\":["
            N=0
            for M in $(model_list); do
              N=$((N+1))
              MK=""; [ "$M" = "$CURM" ] && MK="✅ "
              MDL_KB="$MDL_KB[{\"text\":\"$MK$M\",\"callback_data\":\"mdl:$N\"}],"
            done
            MDL_KB="${MDL_KB%,}]}"
            send_mk "$(printf "$(t mdl_title)" "$(esc "$CURM")" "$(esc "$ALTM")" "$(esc "$GRC")")" "$MDL_KB"
            ;;
          "/alias "*)
            cmd_alias "$TXT"
            ;;
          "/watch"*|"/watch")
            [ "$TXT" = "/watch" ] && TXT="/watch list"
            cmd_watch "$TXT"
            ;;
          "/mon"*|"/mon")
            [ "$TXT" = "/mon" ] && TXT="/mon list"
            cmd_mon "$TXT"
            ;;
          "/key"*|"/key")
            key_cmd "$TXT"
            ;;
          "/reboot")
            date +%s > "$DIR/rbarm"
            reply "$(t rb_arm)"
            send_menu "$(t rb_menu)"
            ;;
          "/reboot yes"|"/reboot  yes")
            ARMED=0
            if [ -f "$DIR/rbarm" ]; then
              A=$(cat "$DIR/rbarm")
              [ $(( $(date +%s) - A )) -le 300 ] && ARMED=1
            fi
            if [ "$ARMED" = "1" ]; then
              rm -f "$DIR/rbarm"
              reply "$(t rb_going)"
              sleep 2
              reboot
              exit 0
            else
              reply "$(t rb_need)"
            fi
            ;;
          *)
            if [ -f "$DIR/aimode" ]; then
              ai_agent "$TXT"
            else
              send_menu "$(help_text)"
            fi
            ;;
        esac
      fi
    fi

    CB=$(jsonfilter -s "$UPDATES" -e "\$.result[$i].callback_query.data" 2>/dev/null)
    if [ -n "$CB" ]; then
      CFROM=$(jsonfilter -s "$UPDATES" -e "\$.result[$i].callback_query.from.id" 2>/dev/null)
      CBID=$(jsonfilter -s "$UPDATES" -e "\$.result[$i].callback_query.id" 2>/dev/null)
      MSGID_CB=$(jsonfilter -s "$UPDATES" -e "\$.result[$i].callback_query.message.message_id" 2>/dev/null)

      if [ "$CFROM" = "$CHAT" ]; then
        answer_cb "$CBID"
        case "$CB" in
          st)
            OUTS="$(status_text)"
            send_rich "$OUTS" || reply "$OUTS"
            ;;
          dv)
            OUTD="$(devices_text)"
            send_rich "$OUTD" || reply "$OUTD"
            KB=$(devices_kb) && send_mk "🏷 Швидкі дії — тапні щоб зробити IP статичним:" "$KB"
            ;;
          st:*)
            D="${CB#st:}"; SMAC="${D%%|*}"; SIP="${D##*|}"
            # Дедуп подвійного тапу: той самий MAC|IP протягом 60с — тільки повідомлення
            CBH=$(printf '%s%s' "$SMAC" "$SIP" | md5sum | cut -c1-8)
            CBSF="$DIR/.cb_$CBH"
            CTN=$(date +%s)
            CBO=$(cat "$CBSF" 2>/dev/null)
            if [ -n "$CBO" ] && [ $(( CTN - CBO )) -le 60 ]; then
              alog CONF "dedup st:$SIP (<60с)"
              reply "✅ Цю аренду вже застосовано секунди тому: <code>$SIP</code>"
            else
              echo "$CTN" > "$CBSF"
              find "$DIR" -name '.cb_*' ! -name "$(basename "$CBSF")" -mmin +60 -exec rm -f {} \; 2>/dev/null
              st_lease_add "$SMAC" "$SIP"
              alog CONF "static lease $SIP $SMAC"
              reply "🏷 <code>$SIP</code> тепер статична аренда ($(esc "$SMAC"))"
            fi
            ;;
          mdl:*)
            MIDX="${CB#mdl:}"
            case "$MIDX" in ""|*[!0-9]*) edit_msg "$MSGID_CB" "$(t ai_pendnone)" "$MENU_MARKUP" ;; *)
            MSEL=$(model_list | sed -n "${MIDX}p")
            if [ -n "$MSEL" ]; then
              uci set tgbot.config.ai_model="$MSEL"
              uci commit tgbot
              alog CONF "primary model -> $MSEL"
              edit_msg "$MSGID_CB" "$(printf "$(t mdl_set)" "$(esc "$MSEL")")" "$MENU_MARKUP"
            else
              edit_msg "$MSGID_CB" "$(t ai_pendnone)" "$MENU_MARKUP"
            fi ;;
            esac
            ;;
          wan)
            reply "$(t wan_run)"
            ifup wan 2>/dev/null
            ;;
          bk)
            cmd_backup
            ;;
          hlp)
            send_menu "$(help_text)"
            ;;
          aion)
            touch "$DIR/aimode"
            rm -f "$DIR/aihist"
            edit_msg "$MSGID_CB" "$(t ai_entered)" "$AI_MARKUP"
            ;;
          aioff)
            rm -f "$DIR/aimode"
            edit_msg "$MSGID_CB" "$(t ai_exitmsg)" "$MENU_MARKUP"
            ;;
          speed)
            edit_msg "$MSGID_CB" "$(t spd_title)

$(t spd_ask)" "$SPD_MARKUP"
            ;;
          spd:d|spd:w|spd:both)
            MODE="${CB#spd:}"
            LABEL="🌐 Напряму"; [ "$MODE" = "warp" ] && LABEL="📡 Через WARP"
            [ "$MODE" = "both" ] && LABEL="Обидва тести"
            MSGID=$(send_mk_getid "$(printf "$(t spd_running)" "$LABEL")")
            [ -z "$MSGID" ] && { reply "$(t spd_fail)"; break; }
            if [ "$MODE" = "both" ]; then
              ( spd_run_one direct "$TOKEN" "$CHAT" "$MSGID" > /tmp/spd_r1.txt; spd_run_one warp "$TOKEN" "$CHAT" "$MSGID" > /tmp/spd_r2.txt; R1=$(cat /tmp/spd_r1.txt); R2=$(cat /tmp/spd_r2.txt); FINAL="$(printf '%s\n\n%s' "$R1" "$R2")"; printf '{"chat_id":"%s","message_id":%s,"text":"%s"}' "$CHAT" "$MSGID" "$(printf '%s' "$FINAL" | sed 's/"/\\"/g')" > /tmp/spd_rq.json; curl -s --max-time 5 "$API/editMessageText" -H "Content-Type: application/json" --data-binary @/tmp/spd_rq.json >/dev/null 2>&1; rm -f /tmp/spd_r1.txt /tmp/spd_r2.txt /tmp/spd_rq.json ) &
            else
              ( RESULT=$(spd_run_one "$MODE" "$TOKEN" "$CHAT" "$MSGID"); printf '{"chat_id":"%s","message_id":%s,"text":"%s"}' "$CHAT" "$MSGID" "$(printf '%s' "$RESULT" | sed 's/"/\\"/g')" > /tmp/spd_rq.json; curl -s --max-time 5 "$API/editMessageText" -H "Content-Type: application/json" --data-binary @/tmp/spd_rq.json >/dev/null 2>&1; rm -f /tmp/spd_rq.json ) &
            fi
            ;;
          aic1)
            C=$(cat "$DIR/aipend" 2>/dev/null)
            rm -f "$DIR/aipend"
            if [ -n "$C" ]; then
              alog CONF "підтверджено: $C"
              case "$C" in
                *"apk "*|*"tar -czf"*|*.zip*)
                  printf '%s' "$C" > "$DIR/.lb_cmd"
                  echo "$MSGID_CB" > "$DIR/.lb_msg"
                  : > "$DIR/.lb_out"; rm -f "$DIR/.lb_done"
                  edit_msg "$MSGID_CB" "⏳ Виконую у фоні — важка команда (до ~2 хв). Результат надішлю окремим повідомленням." 
                  ( OUT=$(ai_run "$C"); printf '%s' "$OUT" > "$DIR/.lb_out"; touch "$DIR/.lb_done" ) &
                  return
                  ;;
              esac
              ai_run "$C"
              act_log "$C" "${RC:-?}"
              state_rebuild
              printf '%s\n%s\n' "$C" "$(date +%s)" > "$DIR/.lastconf"
              alog OUT "CONF→ $(printf '%s' "$OUT" | tr '\n\t' '  ' | head -c 200)"
              edit_msg "$MSGID_CB" "$(printf "$(t ai_done)" "$(esc "$C")" "$(esc "${OUT:-(пусто)}")")" "$MENU_MARKUP"
            else
              edit_msg "$MSGID_CB" "$(t ai_pendnone)" "$MENU_MARKUP"
            fi
            ;;
          aic2)
            C=$(cat "$DIR/aipend" 2>/dev/null)
            rm -f "$DIR/aipend"
            if [ -n "$C" ]; then
              alog CONF "зі страховкою: $C"
              : > "$DIR/.dms_ack"
              case "$C" in
                *"apk "*|*"tar -czf"*|*.zip*)
                  printf '%s' "$C" > "$DIR/.lb_cmd"
                  echo "$MSGID_CB" > "$DIR/.lb_msg"
                  : > "$DIR/.lb_out"; rm -f "$DIR/.lb_done"
                  edit_msg "$MSGID_CB" "⏳ Виконую у фоні — важка команда (до ~2 хв). Результат надішлю окремим повідомленням."
                  ( OUT=$(ai_run "$C"); printf '%s' "$OUT" > "$DIR/.lb_out"; touch "$DIR/.lb_done" ) &
                  return
                  ;;
              esac
              ai_run "$C"
              act_log "$C" "${RC:-?}"
              state_rebuild
              printf '%s\n%s\n' "$C" "$(date +%s)" > "$DIR/.lastconf"
              alog OUT "DMS→ $(printf '%s' "$OUT" | tr '\n\t' '  ' | head -c 200)"
              edit_msg "$MSGID_CB" "$(printf "$(t ai_done)" "$(esc "$C")" "$(esc "${OUT:-(пусто)}")")
⏳ Страхівка: будь-яке ваше повідомлення за 90с = все ок, інакше авто-відкат." "$MENU_MARKUP"
              (
                sleep 90
                [ -f "$DIR/.dms_ack" ] && exit 0
                L=$(ls -d "$DIR/rb/"* 2>/dev/null | tail -n 1)
                [ -z "$L" ] && exit 0
                for CC in network wireless dhcp firewall system sqm; do
                  [ -f "$L/$CC" ] && cp "$L/$CC" "/etc/config/$CC"
                done
                /etc/init.d/network reload 2>/dev/null
                /etc/init.d/dnsmasq restart 2>/dev/null
                /etc/init.d/firewall restart 2>/dev/null
                TT=$(uci -q get tgbot.config.token); CCH=$(uci -q get tgbot.config.chatid)
                curl -s --max-time 10 -H "Content-Type: application/json" \
                  -d "{\"chat_id\":\"$CCH\",\"text\":\"💀 DMS: 90с без вашого сигналу — конфіги відкотто з $L\"}" \
                  "https://api.telegram.org/bot$TT/sendMessage" >/dev/null 2>&1
                echo "$(date +%s)" > "$DIR/.sess"
              ) &
            else
              edit_msg "$MSGID_CB" "$(t ai_pendnone)" "$MENU_MARKUP"
            fi
            ;;
          aic0)
            rm -f "$DIR/aipend"
            alog CONF "скасовано користувачем"
            edit_msg "$MSGID_CB" "$(t ai_cancelled)" "$MENU_MARKUP"
            ;;
          qr)
            cmd_qr
            ;;
          scn)
            cmd_scan
            ;;
          rb1)
            date +%s > "$DIR/rbarm"
            edit_msg "$MSGID_CB" "$(t rb_sure)" "$CONFIRM_MARKUP"
            ;;
          rbyes)
            ARMED=0
            if [ -f "$DIR/rbarm" ]; then
              A=$(cat "$DIR/rbarm")
              [ $(( $(date +%s) - A )) -le 300 ] && ARMED=1
            fi
            if [ "$ARMED" = "1" ]; then
              rm -f "$DIR/rbarm"
              edit_msg "$MSGID_CB" "$(t rb_going)"
              sleep 2
              reboot
            else
              reply "$(t rb_exp)"
            fi
            ;;
          wch)
            watch_menu_ui
            edit_msg "$MSGID_CB" "$WTXT" "$WMK"
            ;;
          wadd:*)
            MC=$(printf '%s' "${CB#wadd:}" | tr 'a-f' 'A-F')
            LMAC=$(printf '%s' "$MC" | tr 'A-F' 'a-f')
            IP=$(awk -v m="$LMAC" 'tolower($2)==m {print $3; exit}' /tmp/dhcp.leases 2>/dev/null)
            NM=$(alias_of "$IP")
            [ -z "$NM" ] && NM=$(awk -v m="$LMAC" 'tolower($2)==m {print $4; exit}' /tmp/dhcp.leases 2>/dev/null)
            [ "$NM" = "*" ] && NM=""
            [ -z "$NM" ] && NM="$(t g_pre)-${MC##*:}"
            grep -vi "^$MC|" "$DIR/presence.cfg" 2>/dev/null > "$DIR/pc.new"
            mv "$DIR/pc.new" "$DIR/presence.cfg"
            echo "$MC|$NM" >> "$DIR/presence.cfg"
            reply "$(printf "$(t w_follow)" "$(esc "$NM")" "$MC")"
            ;;
          wdel:*)
            MC=$(printf '%s' "${CB#wdel:}" | tr 'a-f' 'A-F')
            NM=$(grep -i "^$MC|" "$DIR/presence.cfg" 2>/dev/null | cut -d'|' -f2)
            grep -vi "^$MC|" "$DIR/presence.cfg" 2>/dev/null > "$DIR/pc.new"
            mv "$DIR/pc.new" "$DIR/presence.cfg"
            reply "$(printf "$(t w_unfol)" "$(esc "${NM:-$MC}")")"
            ;;
          mn)
            edit_msg "$MSGID_CB" "$(menu_text)" "$MENU_MARKUP"
            ;;
          mnu:wifi)
            edit_msg "$MSGID_CB" "$(t w_title)" "$WIFI_MARKUP"
            ;;
          mnu:fw)
            edit_msg "$MSGID_CB" "$(t f_title)" "$FW_MARKUP"
            ;;
          fwlist)
            KB=$(fw_kb)
            if [ -n "$KB" ]; then
              send_mk "$(t fw_hdr)" "$KB"
            else
              reply "$(t fw_none)"
            fi
            ;;
          fwdel:*)
            IDX="${CB#fwdel:}"
            case "$IDX" in ''|*[!0-9]*) ;; *)
              SP=$(uci -q get firewall.@redirect[$IDX].src_dport 2>/dev/null)
              if [ -n "$SP" ]; then
                fw_confirm "uci -q delete firewall.@redirect[$IDX] && uci commit firewall && /etc/init.d/firewall restart"
              else
                reply "$(t ai_pendnone)"
              fi
            ;; esac
            ;;
          fwa)
            PROTO_KB="{\"inline_keyboard\":[[{\"text\":\"TCP\",\"callback_data\":\"fst:tcp\"},{\"text\":\"UDP\",\"callback_data\":\"fst:udp\"},{\"text\":\"TCP+UDP\",\"callback_data\":\"fst:any\"}]]}"
            edit_msg "$MSGID_CB" "$(t fw_ask_proto)" "$PROTO_KB"
            ;;
          fst:*)
            PR="${CB#fst:}"
            case "$PR" in tcp|udp|any) mact_set "fwa_e:$PR"; reply "$(t fw_ask_eport)" ;; esac
            ;;
          pkgl)
            mact_set "pkg:q"; reply "$(t pk_ask)"
            ;;
          pki:*|pkr:*)
            PN="${CB#pki:}"; [ "$CB" = "$PN" ] && PN="${CB#pkr:}"
            case "$PN" in *[!a-zA-Z0-9._-]*|"") reply "$(t ai_pendnone)" ;;
              *)
                case "$CB" in pki:*) PCC="apk add $PN" ;; *) PCC="apk del $PN" ;; esac
                printf '%s' "$PCC" > "$DIR/aipend"
                send_mk "$(printf "$(t wf_conf)" "$(esc "$PCC")")" "$AI_CONF2_MARKUP"
            ;; esac
            ;;
          sshkl)
            SKB=""; NK=0
            if [ -s /etc/dropbear/authorized_keys ]; then
              while IFS= read -r KL; do
                NK=$((NK+1))
                KT=$(printf '%s' "$KL" | awk '{print $1}'); KT=${KT:-key}
                KB4=$(printf '%s' "$KL" | awk '{print substr($2,length($2)-7)}')
                SKB="$SKB[{\"text\":\"❌ $NK: $KT …$KB4\",\"callback_data\":\"sshkd:$NK\"}],"
                [ $NK -ge 8 ] && break
              done < /etc/dropbear/authorized_keys
            fi
            SKB=${SKB%,}
            SSH_KB="{\"inline_keyboard\":["
            [ -n "$SKB" ] && SSH_KB="$SSH_KB$SKB,"
            SSH_KB="$SSH_KB[{\"text\":\"$(t ssh_add)\",\"callback_data\":\"ssha\"}],[{\"text\":\"$(t mnback)\",\"callback_data\":\"mnu:sys\"}]]}"
            edit_msg "$MSGID_CB" "🔑 <b>/etc/dropbear/authorized_keys</b>\nТап по ключу — удалить:" "$SSH_KB"
            ;;
          ssha)
            mact_set "sshk:a"; reply "$(t ssh_ask)"
            ;;
          sshkd:*)
            NKEY="${CB#sshkd:}"
            case "$NKEY" in ''|*[!0-9]*) ;; *)
              TOTK=$(wc -l < /etc/dropbear/authorized_keys 2>/dev/null)
              if [ -n "$TOTK" ] && [ "$NKEY" -ge 1 ] && [ "$NKEY" -le "$TOTK" ]; then
                fw_confirm "sed -i '${NKEY}d' /etc/dropbear/authorized_keys"
              else
                reply "$(t ai_pendnone)"
              fi
            ;; esac
            ;;
          mnu:dg)
            edit_msg "$MSGID_CB" "$(t d_title)" "$DG_MARKUP"
            ;;
          dgt:*)
            DT="${CB#dgt:}"
            case "$DT" in ping|trace|ns) mact_set "dg:$DT"; reply "$(t dg_ask)" ;; esac
            ;;
          dgl:*)
            DL="${CB#dgl:}"
            case "$DL" in
              logread)
                logread 2>/dev/null | tail -n 150 > "$DIR/.logdoc" ;;
              dmesg)
                dmesg 2>/dev/null | tail -n 150 > "$DIR/.logdoc" ;;
              *) : ;;
            esac
            if [ -s "$DIR/.logdoc" ]; then
              reply_doc "$DIR/.logdoc" "📜 $DL (останні 150 рядків)"
              reply "$(t dg_logsent)"
            else
              reply "$(t ai_noans)"
            fi
            ;;
          mnu:sys)
            edit_msg "$MSGID_CB" "$(t s_title)" "$SYS_MARKUP"
            ;;
          mnu:vpn)
            edit_msg "$MSGID_CB" "$(t vpn_title)" "$VPN_MARKUP"
            ;;
          wst)
            warp_status_text
            edit_msg "$MSGID_CB" "$OUTW" "$VPN_MARKUP"
            ;;
          wmtu)
            if [ ! -f "$DIR/warp.reg" ] || ! uci -q get network.warp >/dev/null 2>&1; then
              edit_msg "$MSGID_CB" "$(t v_noconf)" "$VPN_MARKUP"
            else
              printf '%s' "📏 MTU test" > "$DIR/.lb_cmd"
              echo "$MSGID_CB" > "$DIR/.lb_msg"; : > "$DIR/.lb_out"; rm -f "$DIR/.lb_done"
              reply "$(t v_mtu_run)"
              ( eval "$(warp_mtu_script)" ) >/dev/null 2>&1 &
            fi
            ;;
          wmtua:*)
            N="${CB#wmtua:}"
            case "$N" in 1420|1400|1380|1280)
              printf '%s' "uci set network.@wireguard_warp[0].mtu='$N' && uci commit network && ifup warp && sleep 3 && wg show warp latest-handshakes" > "$DIR/aipend"; date +%s > "$DIR/.apts"
              send_mk "$(printf "$(t ai_confirm)" "uci set network.@wireguard_warp[0].mtu='$N'")" "$AI_CONF2_MARKUP"
            ;; esac
            ;;
          wep)
            if [ ! -f "$DIR/warp.reg" ] || ! uci -q get network.warp >/dev/null 2>&1; then
              edit_msg "$MSGID_CB" "$(t v_noconf)" "$VPN_MARKUP"
            else
              printf '%s' "📡 Endpoint ping" > "$DIR/.lb_cmd"
              echo "$MSGID_CB" > "$DIR/.lb_msg"; : > "$DIR/.lb_out"; rm -f "$DIR/.lb_done"
              reply "$(t v_ep_run)"
              ( eval "$(warp_ep_script)" ) >/dev/null 2>&1 &
            fi
            ;;
          wepa:*)
            IPV="${CB#wepa:}"
            case "$IPV" in
              *[!0-9.]*|""|*..*) edit_msg "$MSGID_CB" "$(t ai_pendnone)" "$VPN_MARKUP" ;;
              *)
                printf '%s' "uci set network.@wireguard_warp[0].endpoint_host='$IPV' && uci commit network && /etc/init.d/network reload && sleep 6 && wg show warp latest-handshakes" > "$DIR/aipend"; date +%s > "$DIR/.apts"
                send_mk "$(printf "$(t ai_confirm)" "endpoint → $IPV")" "$AI_CONF2_MARKUP"
            ;; esac
            ;;
          pbr_menu)
            if [ ! -f "$DIR/warp.reg" ] || ! uci -q get network.warp >/dev/null 2>&1; then
              edit_msg "$MSGID_CB" "$(t pbr_no_warp)" "$VPN_MARKUP"
            else
              PCNT=$(wc -l < "$DIR/blocked.list" 2>/dev/null || echo 0)
              edit_msg "$MSGID_CB" "$(printf "$(t pbr_title)" "$PCNT")" "$PBR_MARKUP"
            fi
            ;;
          pbr_list)
            if [ ! -f "$DIR/warp.reg" ] || ! uci -q get network.warp >/dev/null 2>&1; then
              edit_msg "$MSGID_CB" "$(t pbr_no_warp)" "$VPN_MARKUP"
            else
              PCNT=$(wc -l < "$DIR/blocked.list" 2>/dev/null || echo 0)
              if [ "$PCNT" -eq 0 ]; then
                edit_msg "$MSGID_CB" "$(t pbr_empty)" "$PBR_MARKUP"
              else
                PNUM=0; PLIST=""
                while IFS= read -r L; do
                  PNUM=$((PNUM+1)); PLIST="$PLIST
$PNUM. $L"
                done < "$DIR/blocked.list"
                edit_msg "$MSGID_CB" "$(printf "$(t pbr_title)" "$PCNT")
$PLIST" "$PBR_MARKUP"
              fi
            fi
            ;;
          pbr_add_ask)
            if [ ! -f "$DIR/warp.reg" ] || ! uci -q get network.warp >/dev/null 2>&1; then
              edit_msg "$MSGID_CB" "$(t pbr_no_warp)" "$VPN_MARKUP"
            else
              mact_set "pbr_add"
              reply "$(t pbr_add_ask)"
            fi
            ;;
          pbr_del)
            if [ ! -f "$DIR/blocked.list" ] || [ ! -s "$DIR/blocked.list" ]; then
              edit_msg "$MSGID_CB" "$(t pbr_empty)" "$PBR_MARKUP"
            else
              PNUM=0; PLINES=""
              while IFS= read -r L; do
                PNUM=$((PNUM+1))
                PLINES="$PLINES[{\"text\":\"$PNUM. $L\",\"callback_data\":\"pbr_del:$PNUM\"}],"
              done < "$DIR/blocked.list"
              PLINES="${PLINES%,}"
              PDEL_MARKUP="{\"inline_keyboard\":[[$PLINES],[{\"text\":\"$(t mnback)\",\"callback_data\":\"pbr_menu\"}]]}"
              edit_msg "$MSGID_CB" "🗑 Виберіть запис для видалення:" "$PDEL_MARKUP"
            fi
            ;;
          pbr_del:*)
            PNUM="${CB#pbr_del:}"
            case "$PNUM" in ''|*[!0-9]*) ;; *)
              LINE=$(sed -n "${PNUM}p" "$DIR/blocked.list" 2>/dev/null)
              if [ -n "$LINE" ]; then
                sed -i "${PNUM}d" "$DIR/blocked.list"
                reply "$(printf "$(t pbr_del_ok)" "$LINE")"
                PCNT=$(wc -l < "$DIR/blocked.list" 2>/dev/null || echo 0)
                edit_msg "$MSGID_CB" "$(printf "$(t pbr_title)" "$PCNT")" "$PBR_MARKUP"
              else
                edit_msg "$MSGID_CB" "$(t pbr_empty)" "$PBR_MARKUP"
              fi
            ;; esac
            ;;
          pbr_apply)
            if [ ! -f "$DIR/warp.reg" ] || ! uci -q get network.warp >/dev/null 2>&1; then
              edit_msg "$MSGID_CB" "$(t pbr_no_warp)" "$VPN_MARKUP"
            elif [ ! -f "$DIR/blocked.list" ] || [ ! -s "$DIR/blocked.list" ]; then
              edit_msg "$MSGID_CB" "$(t pbr_empty_err)" "$PBR_MARKUP"
            else
              if [ "$(cat "$DIR/.pbr_active" 2>/dev/null)" = "1" ]; then
                eval "$(pbr_clear_script)"
                : > "$DIR/.pbr_active"
                edit_msg "$MSGID_CB" "$(t pbr_clear)" "$VPN_MARKUP"
              else
                uci set network.@wireguard_warp[0].route_allowed_ips='0'
                uci commit network
                /etc/init.d/network reload >/dev/null 2>&1
                sleep 3
                eval "$(pbr_apply_script)"
                echo 1 > "$DIR/.pbr_active"
                PCNT=$(wc -l < "$DIR/blocked.list" 2>/dev/null || echo 0)
                edit_msg "$MSGID_CB" "$(printf "$(t pbr_apply)" "$PCNT")" "$VPN_MARKUP"
              fi
            fi
            ;;
          wonp)
            if [ ! -f "$DIR/warp.reg" ] || ! uci -q get network.warp >/dev/null 2>&1; then
              edit_msg "$MSGID_CB" "$(t pbr_no_warp)" "$VPN_MARKUP"
            elif [ ! -f "$DIR/blocked.list" ] || [ ! -s "$DIR/blocked.list" ]; then
              edit_msg "$MSGID_CB" "$(t pbr_empty_err)" "$PBR_MARKUP"
            else
              uci set network.@wireguard_warp[0].route_allowed_ips='0'
              uci commit network
              /etc/init.d/network reload >/dev/null 2>&1
              sleep 3
              eval "$(pbr_apply_script)"
              echo 1 > "$DIR/.pbr_active"
              PCNT=$(wc -l < "$DIR/blocked.list" 2>/dev/null || echo 0)
              reply "$(printf "$(t pbr_apply)" "$PCNT")"
              warp_status_text
              edit_msg "$MSGID_CB" "$OUTW" "$VPN_MARKUP"
            fi
            ;;
          wup1)
            edit_msg "$MSGID_CB" "$(t v_reg_ask)" "$WARP_CONF_MARKUP"
            ;;
          wgo)
            printf '%s' "⚡️ WARP setup" > "$DIR/.lb_cmd"
            echo "$MSGID_CB" > "$DIR/.lb_msg"
            : > "$DIR/.lb_out"; rm -f "$DIR/.lb_done"
            reply "$(t v_reg_run)"
            ( DIR="$DIR"; CHAT="$CHAT"; eval "$(warp_reg_script)" ) &
            ;;
          won)
            if [ ! -f "$DIR/warp.reg" ] || ! uci -q get network.warp >/dev/null 2>&1; then
              edit_msg "$MSGID_CB" "$(t v_noconf)" "$VPN_MARKUP"
            else
              i=0; FWD=""
              while :; do FS=$(uci -q get firewall.@forwarding[$i].src 2>/dev/null) || break
                FD=$(uci -q get firewall.@forwarding[$i].dest 2>/dev/null)
                [ "$FS" = "lan" ] && [ "$FD" = "warp" ] && FWD=1 && break; i=$((i+1)); done
              CMDL="uci set network.@wireguard_warp[0].route_allowed_ips='1'"
              [ -z "$FWD" ] && CMDL="$CMDL && uci add firewall forwarding && uci set firewall.@forwarding[-1].src='lan' && uci set firewall.@forwarding[-1].dest='warp' && uci commit firewall"
              CMDL="$CMDL && uci commit network && /etc/init.d/firewall restart && sleep 3"
              [ -f "$DIR/.pbr_active" ] && CMDL="$CMDL && $(printf '%s' "$(pbr_clear_script)" | tr '\n' ' ') && rm -f $DIR/.pbr_active"
              CMDL="$CMDL && curl -s --max-time 8 --interface warp https://www.cloudflare.com/cdn-cgi/trace | head -4"
              printf '%s' "$CMDL" > "$DIR/aipend"; date +%s > "$DIR/.apts"
              send_mk "$(printf "$(t v_aon_warn)" "$(esc "${CMDL:0:200}…")")" "$AI_CONF2_MARKUP"
            fi
            ;;
          woff)
            if ! uci -q get network.warp >/dev/null 2>&1; then
              edit_msg "$MSGID_CB" "$(t v_noconf)" "$VPN_MARKUP"
            else
              PBRCL=""; [ -f "$DIR/.pbr_active" ] && PBRCL=" && $(printf '%s' "$(pbr_clear_script)" | tr '\n' ' ') && rm -f $DIR/.pbr_active"
              printf '%s' "uci set network.@wireguard_warp[0].route_allowed_ips='0' && uci commit network && /etc/init.d/network reload${PBRCL}" > "$DIR/aipend"; date +%s > "$DIR/.apts"
              send_mk "$(printf "$(t ai_confirm)" "$(esc "$(cat "$DIR/aipend")")")" "$AI_CONF2_MARKUP"
            fi
            ;;
          wdel1)
            if ! uci -q get network.warp >/dev/null 2>&1; then
              edit_msg "$MSGID_CB" "$(t v_noconf)" "$VPN_MARKUP"
            else
              edit_msg "$MSGID_CB" "$(t v_del_ask)" "$WDEL_CONF_MARKUP"
            fi
            ;;
          wdel2)
            (
              ifdown warp 2>/dev/null
              while uci -q delete network.@wireguard_warp[0] >/dev/null 2>&1; do :; done
              uci -q delete network.warp >/dev/null 2>&1
              N=$(uci show firewall | grep -c '=forwarding')
              i=$((N-1))
              while [ "$i" -ge 0 ]; do
                FS=$(uci -q get firewall.@forwarding[$i].src 2>/dev/null)
                FD=$(uci -q get firewall.@forwarding[$i].dest 2>/dev/null)
                [ "$FS" = "lan" ] && [ "$FD" = "warp" ] && uci -q delete firewall.@forwarding[$i] >/dev/null 2>&1
                i=$((i-1))
              done
              Z=$(uci show firewall | grep -c '=zone')
              i=$((Z-1))
              while [ "$i" -ge 0 ]; do
                [ "$(uci -q get firewall.@zone[$i].name 2>/dev/null)" = "warp" ] && uci -q delete firewall.@zone[$i] >/dev/null 2>&1
                i=$((i-1))
              done
              uci commit network; uci commit firewall
              /etc/init.d/firewall restart >/dev/null 2>&1
              rm -f "$DIR/warp.reg"
              act_log "warp delete" 0
              state_rebuild
            )
            edit_msg "$MSGID_CB" "$(t vpn_title)

🗑 WARP видалено." "$VPN_MARKUP"
            ;;
          wfkb)
            KB=$(wf_kb) && send_mk "$(t wf_pick)" "$KB" || reply "$(t wf_none)"
            ;;
          wf:*)
            IDX="${CB#wf:}"
            if wf_view "$IDX"; then
              edit_msg "$MSGID_CB" "$OUTW" "$WF_KB"
            else
              reply "$(t wf_none)"
            fi
            ;;
          wfk:*|wfs:*|wfc:*)
            mact_set "$CB"
            case "$CB" in
              wfk:*) reply "$(t wf_ask_key)" ;;
              wfs:*) reply "$(t wf_ask_ssid)" ;;
              *) reply "$(t wf_ask_ch)" ;;
            esac
            ;;
          wfp:*)
            IDX="${CB#wfp:}"
            case "$IDX" in ''|*[!0-9]*) ;; *)
              PWR_KB="{\"inline_keyboard\":[[{\"text\":\"📉 10 dBm\",\"callback_data\":\"wpz:$IDX:10\"},{\"text\":\"📊 20 dBm\",\"callback_data\":\"wpz:$IDX:20\"},{\"text\":\"🚀 max\",\"callback_data\":\"wpz:$IDX:max\"}],[{\"text\":\"$(t mnback)\",\"callback_data\":\"wf:$IDX\"}]]}"
              edit_msg "$MSGID_CB" "💪 $(t wf_b_pwr)" "$PWR_KB"
            ;; esac
            ;;
          wpz:*)
            R="${CB#wpz:}"; IDX="${R%%:*}"; V="${R##*:}"
            D=$(uci -q get wireless.@wifi-iface[$IDX].device 2>/dev/null)
            if [ -n "$D" ]; then
              case "$V" in
                10|20) wf_apply "uci set wireless.$D.txpower='$V'" ;;
                max) wf_apply "uci -q delete wireless.$D.txpower" ;;
              esac
            fi
            ;;
          wft:*)
            IDX="${CB#wft:}"
            D=$(uci -q get wireless.@wifi-iface[$IDX].device 2>/dev/null)
            if [ -n "$D" ]; then
              DIS=$(uci -q get wireless.$D.disabled 2>/dev/null)
              if [ "${DIS:-0}" = "1" ]; then
                wf_apply "uci -q delete wireless.$D.disabled"
              else
                wf_apply "uci set wireless.$D.disabled='1'"
              fi
            fi
            ;;
          rbk1)
            date +%s > "$DIR/rbkarm"
            edit_msg "$MSGID_CB" "$(t rbk_arm)" "$RBK_CONF_MARKUP"
            ;;
          rbkyes|rbkno)
            if [ "$CB" = "rbkno" ]; then
              rm -f "$DIR/rbkarm"
              edit_msg "$MSGID_CB" "$(t ai_cancelled)" "$MENU_MARKUP"
            else
              ARMED=0
              if [ -f "$DIR/rbkarm" ]; then
                A=$(cat "$DIR/rbkarm")
                [ $(( $(date +%s) - A )) -le 300 ] && ARMED=1
              fi
              L=$(ls -d "$DIR/rb/"* 2>/dev/null | tail -n 1)
              if [ "$ARMED" != "1" ]; then
                edit_msg "$MSGID_CB" "$(t rbk_exp)" "$MENU_MARKUP"
              elif [ -z "$L" ]; then
                edit_msg "$MSGID_CB" "$(t rbk_none)" "$SYS_MARKUP"
              else
                rm -f "$DIR/rbkarm"
                for CC in network wireless dhcp firewall system sqm; do
                  [ -f "$L/$CC" ] && cp "$L/$CC" "/etc/config/$CC"
                done
                /etc/init.d/network reload 2>/dev/null
                /etc/init.d/dnsmasq restart 2>/dev/null
                /etc/init.d/firewall restart 2>/dev/null
                alog CONF "rollback -> $L (кнопка)"
                edit_msg "$MSGID_CB" "$(printf "$(t rbk_ok)" "$(basename "$L")")" "$SYS_MARKUP"
              fi
            fi
            ;;
          al)
            reply "$(alias_help)"
            ;;
          rbno)
            edit_msg "$MSGID_CB" "$(menu_text)" "$MENU_MARKUP"
            ;;
        esac
      fi
    fi

    i=$((i+1))
  done

  if [ -n "$LAST" ]; then
    echo $((LAST+1)) > "$DIR/offset"
  fi
}

# --- ежечасный пульс ---
check_pulse() {
  NOW=$(date +%s)
  LP=0
  [ -f "$DIR/lastpulse" ] && LP=$(cat "$DIR/lastpulse")
  # F: щодобовий повний refresh кешу стану роутера (WAN IP тощо можуть змінитись самі)
  state_fresh || state_rebuild
  if [ $((NOW-LP)) -ge $PULSE_INTERVAL ]; then
    pulse_edit_or_send "$(printf "$(t pulse)" "$(uptime_short)" "$(internet_ok)" "$(date '+%H:%M')")"
    echo "$NOW" > "$DIR/lastpulse"
  fi
}

# --- регистрация команд в меню Telegram (кнопка ☰) ---
mk_markups
register_commands
LASTLANG="$BOT_LANG"

# --- главный цикл демона ---
NEXTCHK=0
while true; do
  # Доставка результату фонової важкої команди
  if [ -f "$DIR/.lb_done" ]; then
    RES=$(head -c 1500 "$DIR/.lb_out" 2>/dev/null)
    MID=$(cat "$DIR/.lb_msg" 2>/dev/null); CMDD=$(cat "$DIR/.lb_cmd" 2>/dev/null)
    rm -f "$DIR/.lb_done"
    act_log "$CMDD" "?"
    state_rebuild
    [ -n "$MID" ] && edit_msg "$MID" "$(printf "$(t ai_done)" "$(esc "$CMDD")" "$(esc "${RES:-(пусто)}")")"
    printf '%s\n%s\n' "$CMDD" "$(date +%s)" > "$DIR/.lastconf"
  fi
  CL="$(uci -q get tgbot.config.lang 2>/dev/null)"
  [ -z "$CL" ] && CL="${TGBOT_LANG:-ru}"
  case "$CL" in en|uk|ru) ;; *) CL=ru ;; esac
  if [ "$CL" != "$LASTLANG" ]; then
    BOT_LANG="$CL"
    LASTLANG="$CL"
    mk_markups
    register_commands
  fi
  process_updates
  check_pulse
  NOW=$(date +%s)
  if [ "$NOW" -ge "$NEXTCHK" ]; then
    do_checks
    NEXTCHK=$((NOW+60))
  fi
done
