# OpenWrt: сервіси (SQM, облік трафіку, DDNS, UPnP, WoL, USB, cron)
## SQM/QoS (cake) — головні ліки від bufferbloat:
apk add sqm-scripts luci-app-sqm (~200КБ). /etc/config/sqm: interface 'pppoe-wan' (НЕ eth!), download/upload = 85-90% РЕАЛЬНИХ швидкостей (speedtest без SQM спершу), queue_discipline 'cake', script 'piece_of_cake'.
На mipsel: cake жере CPU — при >100Мбіт каналі дивись top; тоді piece_of_cake→'fq_codel'? cake simplest ok до ~150Мбіт.
Включення/виключення: /etc/init.d/sqm start|stop. Перевірка ефекту: waveform bufferbloat test; ping під час завантаження має залишатись <30мс надбавки.
## Облік по клієнтах — nlbwmon:
apk add nlbwmon luci-app-nlbwmon. БД в RAM (tmpfs): /etc/config/nlbwmon option commit_interval, database_interval; перезавантаження роутера = історія зникає (чесно попередити; USB для персистенції).
CLI: nlbw show? Основне через LuCI; наш бот рахує сам через /proc/net/nf_conntrack | awk для live.
## DDNS (домен на динамічний IP):
apk add ddns-scripts (+ddns-scripts-services). /etc/config/ddns: service_name 'cloudflare.com-v4'|'no-ip.com'; update_url; username(зона CF)/password(API token); ip_source 'network' interface 'wan'; check_interval '10'; force_interval '72h'
Перевірка: logread | grep ddns; curl ifconfig.me
## UPnP (ігри/консолі):
miniupnpd: apk add miniupnpd luci-app-upnp. Зона+port range у конфізі. БЕЗПЕКА: увімкнений UPnP = програми самі відкривають порти — для параноїків вимкнено.
## Wake-on-LAN:
etherwake -i br-lan AA:BB:CC:DD:EE:FF (пакет etherwake ~10КБ). Цільова машина має підтримувати WOL (BIOS+драйвер). Перевірка: ping після 20с.
## USB-накопичення:
kmod-usb-storage block-mount kmod-fs-ext4 → mount: block detect >> /etc/config/fstab; uci редагувати target '/mnt/sda1' enabled '1'; mount /mnt/sda1
Використання: swapfile, торенти НЕ радити, бекапи конфігів, overlay розширення (extroot — складно, але рятує flash).
## Cron (шедулінг власних задач):
crontab -e → '30 6 * * * /usr/bin/mytask.sh'; лог cron: logread | grep cron. Наш tg-analyze вже там (0 * * * *).
## Пастки:
- SQM interface помилка pppoe-wan vs wan device = не працює зовсім
- nlbwmon + великий будинок клієнтів = RAM росте → commit_interval менший
- ddns через CGNAT оновлює «той» IP — марно (див kb diagnostics)
