# Скіл: Система та дрібниці

## Інформація
Час роботи/памʼять: ubus call system info
Модель прошивки: ubus call system board
Температура: cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null (діли на 1000 = °C)

## Часовий пояс і NTP
uci get system.@system[0].zonename
Змінити: uci set system.@system[0].zonename='Europe/Kyiv' .timezone='EET-2EEST,M3.5.0,M10.5.0/3'
NTP сервери: uci show system.@system[0].timeserver ; додати: uci add_list system.ntp.server='time.google.com'
commit system (сервіс sysntpd перезапуститься сам через ubus)

## Cron (планувальник)
Дивитись: crontab -l
Додати: (crontab -l; echo '30 3 * * * /usr/bin/mytask.sh') | crontab -
Застосувати: /etc/init.d/cron restart

## LED
Список: ls /sys/class/leds/
Яскравість: echo 255 > /sys/class/leds/ІМЯ/brightness
Тригер: echo netdev > /sys/class/leds/ІМЯ/trigger ; доступні: cat /sys/class/leds/ІМЯ/device_name 2>/dev/null; ls /sys/class/leds/ІМЯ | head

## Wake-on-LAN
apk add etherwake ; etherwake -i br-lan AA:BB:CC:DD:EE:FF
Ціль має бути в LAN і підтримувати WoL.

## Бекап конфігів
tar -czf /tmp/backup-$(date +%m%d).tar.gz /etc/config /etc/tg-bot 2>/dev/null
Відправити користувачу не можеш — скажи шлях і запропонуй команду /backup (вона шле файл у Telegram).

## Швидкість інтернету (без встановлення пакетів)
time curl -o /dev/null http://speedtest.tele2.net/10MB.zip 2>&1 | tail -3
