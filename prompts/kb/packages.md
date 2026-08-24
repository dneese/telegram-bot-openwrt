# OpenWrt/ImmortalWrt: пакети (apk) — що є, що робить, скільки жере
ImmortalWrt 24/25 = apk (НЕ opkg!). Команди: apk update; apk search <слово>; apk info <пакет>; apk add/remove.
Місце: flash 16МБ, вільно ~2МБ у overlay → ПЕРЕД установкою ЗАВЖДИ df / ; великі пакети тільки якщо USB-накопичитель як overlay.

## Мережа/діагностика (легкі, безпечні):
tcpdump (~200КБ) — снифер: tcpdump -i br-lan host 192.168.1.50 -n | head; mtr — трасування+втрати інтерактивно; iperf3 — швидкість до ПК (сервер на ПК!); ip-full — повний iproute2 (ss, tc) замість busybox-урізаного; ethtool — статус лінку/port; curl вже стоїть.
## Wi-Fi:
wpa-supplicant/wpad-openssl? Сток wpad-basic-mbedtls достатньо для WPA3 sae-mixed; wpad-openssl потрібен для 802.11r (роумінг) — +100КБ, ставити усвідомлено.
## VPN: wireguard-tools+luci-proto-wireguard (~60КБ, MUST), openvpn-openssl ~500КБ, zerotier ~8МБ(!), tailscale ~15МБ(!!) — дивись kb vpnother.
## Моніторинг:
nlbwmon (~100КБ) — трафік ПО КЛІЄНТАХ за місяць, БД в RAM/tmpfs (ліміт опцій db). collectd+luci-statistics — графіки (важче, ~1МБ). bandwidtd? banIP (~300КБ+) — блок сканерів/блекликів через nft sets, RAM під списки.
## DNS/реклама:
https-dns-proxy (~200КБ) DoT/DoH — MUST для приватності; adblock+luci-app-adblock — блеклисти DNS (списки їдять tmpfs 20-40МБ — компактні списки на 128МБ!).
## Файлова/USB:
kmod-usb-storage + block-mount + kmod-fs-ext4/exfat (~150КБ разом) — флешка як /mnt/sda1; samba4-server ВАЖКИЙ (~3МБ+RAM 15МБ+) → краще mini_fo? Ні: dla 128МБ чесно радити vsftpd (~100КБ) або scp/dropbear вже є.
## Системне:
irqbalance НЕ треба (одноядерний!), zram-swap (~30КБ, +стиснутий swap 32МБ — рятує від OOM ціною CPU), cron системний уже є (crontab -e), htop (~50КБ) для живого огляду.
## LuCI-додатки (кожен ~20-150КБ):
luci-app-sqm, -nlbwmon, -wireguard, -adblock, -mwan3(~+400КБ), -openvpn, -upnp...
Правило: LuCI-апки лише якщо власник юзає веб; боту вони не потрібні.
## ЧОГО НЕ СТАВИТИ на 128МБ mipsel:
docker (нема навіть збірок), nextcloud/pihole-in-container, transmission (RAM-жер), jellyfin — це все для x86.
samba4 повний, asterisk, tor (повільно+RAM).
## Гігієна:
apk del звільняє overlay не завжди повністю (залишки в /usr/lib/opkg? в apk — /lib/apk/db). Після великих експериментів — перевстановлення чистіше.
Список встановленого: apk info | sort; що тягнув пакет: apk info -R <pkg> (залежності), apk info -s <pkg> (розмір).
