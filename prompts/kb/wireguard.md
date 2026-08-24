# OpenWrt: WireGuard повні рецепти
Пакет: apk add wireguard-tools luci-proto-wireguard (~60КБ, CPU-friendly — ідеально для mipsel).

## СЕРВЕР (roadwarrior — телефон/ноут ззовні):
uci set wg0=interface; proto='wireguard'; private_key='<wg genkey>'; listen_port='51820'; addresses='10.9.0.1/24'
uci add_list network.wg0... route_allowed_ips? Ні: allowed_ips для peer.
Peer (телефон): public_key його pubkey; allowed_ips='10.9.0.2/32'; option persistent_keepalive='25'
Файрвол: zone wan → add_list network 'wg0'? НІ — окрема зона wg: input ACCEPT (для handshake), forward to lan ACCEPT, masq '1' якщо вихід клієнтів через роутера.
Port forward НЕ потрібен якщо wg0 у своїй зоні з input accept на wan-інтерфейсі... Правильно: rule src='wan' proto='udp' dest_port='51820' target='ACCEPT'.
Генерация пар ключів НА РОУТЕРІ: wg genkey | tee /tmp/priv | wg pubkey > /tmp/pub
QR для телефону (без камери не треба, але): apk add qrencode; qrencode -t ansiutf8 < peer.conf
## КЛІЄНТ (роутер → інший WG/VPS):
proto wireguard, addresses 10.9.0.2/24; peer: endpoint='vpn.example.com:51820', allowed_ips='0.0.0.0/0' (все) або список підсеток; persistent_keepalive='25'.
PBR через тунель тільки для вибраних пристроїв: окремий interface+зона+rule src_ip → forward via wg.
## Killswitch (все тільки через VPN):
firewall: zone vpnout forward wan REJECT... Простіше: правило REJECT lan→wan + ACCEPT lan→wg0 для потрібних IP-хостів.
## site2site:
Обмінятись allowed_ips підмережами обох сторін + routes автоматично (route_allowed_ips='1') + на обох firewall forwarding між зонами wg↔lan.
## Діагностика:
wg show (handshake свіжий? transfer рахується?)
ping 10.9.0.1 зсередини тунелю
logread | grep wireguard
MTU: типово 1420; якщо PPPoE/криві шляхи — спробувати 1380-1412: option mtu.
## Пастки:
- allowed_ips мусить бути унікальним між peers (перекриття = тихий збій маршрутизації)
- NAT-refresh: keepalive 25s тримає діру в NAT для вихідних клієнтів
- час! handshake валиться при зсуві годинника — sysntpd має працювати
