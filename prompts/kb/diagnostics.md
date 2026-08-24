# Діагностика: типові проблеми інтернету і рішення (методика + рецепти)
Загальний порядок: фізика → лінк → адреса → DNS → маршрут → NAT. Кожен крок = одна команда.

## 1. Немає навіть лінку на WAN
ip link show wan / ethtool wan (Link detected?)
→ кабель/порто-розетка; спробувати інший порт lan як WAN не можна (апаратно один WAN), але перевір кримзни.
## 2. Лінк є, IP немає (DHCP від провайдера)
logread | grep -E "udhcpc|dhcp" на wan; uci get network.wan.proto
→ proto dhcp? udhcpc «no lease» = провайдер бачить не ту MAC (прив'язка!) або вимагає VLAN.
MAC привʼязка: uci set network.wan.macaddr='MAC_старого_роутера' && ifup wan
ISP VLAN (деякі): network.wan.device='wan.VID'? DSA: створити wan.10 vlan device — дивись kb network.
## 3. PPPoE: зʼєднання падає/повільно
uci show network.wan | grep -E "username|password|mtu"; logread | grep pppd
MTU/MRU 1492 (VDSL інколи 1480 з VLAN); «PPPoE timeout» → перевір кабель-пари (2 пари vs 4), гирляндний шнур.
Постійні reconnects раз на N хв = ISP session idle → option keepalive '5 1'.
## 4. IP є, ping 8.8.8.8 є, сайти не відкриваються → DNS
nslookup google.com; nslookup google.com 1.1.1.1 (якщо так працює → DNS провайдера мертвий):
uci add_list dhcp.@dnsmasq[0].server='1.1.1.1'; uci set dhcp.@dnsmasq[0].noresolv='1'; commit dhcp; restart dnsmasq
IPv6-витік: клієнт бере IPv6 DNS провайдера який мертвий → тимчасово вимкнути RA: dhcp.lan.ra='disable'? Точково ra_management... чесно: firewall REJECT udp 53 до чужих + redirect 53 на роутера.
## 5. CGNAT (найчастіше «чому проброс не працює»)
WAN-адреса 100.64.0.0/10 (або збігається з traceroute-хвостами) = NAT провайдера:
ip addr show pppoe-wan | grep inet; traceroute 1.1.1.1
Рішення: тільки VPN-тунель до себе (VPS WireGuard) або IPv6. Проброси марні — ЧЕСНО кажи користувачу.
## 6. Подвійний NAT (роутер за роутером)
traceroute: перший хоп не твій WAN-IP. Рішення: режим AP (відключи DHCP на lan, увімкни bridge) або cable в LAN-port замість WAN.
## 7. Wi-Fi підключається, «без інтернету»
Клієнт отримав IP? arp; пінг зі сторони клієнта 192.168.1.1 потім 8.8.8.8.
Гостьова мережа без правил forwarding → ізоляція блокує все (дивись kb wireless).
WPA3-only + старий клієнт → sae-mixed.
## 8. Інтернет пропадає періодично у ВСІХ
logread на момент падіння: pppd exit / udhcpc renew / link down?
Тепло! перевір температуру: cat /sys/class/thermal/thermal_zone0/temp (>80°C = чистити/підняти)
DHCP lease провайдера короткий+renew fail → дивись час у логах.
## 9. Повільно ВЕСЬ трафік (не тільки Wi-Fi)
CPU: top (softirq ≈100% = ліміт NAT/CPU); flow offload дивись kb performance.
SQM задушить якщо misconfigured: uci get sqm.@queue[0].download
Дуплекс: ethtool wan (100 vs 1000, half=біда)
## 10. OOM-вбивства/фрізи
dmesg | grep -i "oom\|out of memory"; free
Злодії: adblock великі списки, tailscale, samba4. → zram-swap або прибрати злодія.
## 11. Flash переповнений
df / ; apk add падає «no space». → apk del сміття, списки adblock менші, USB-overlay.
## Золота правило: після КОЖНОЇ зміни — верифікаційна команда і тільки потім «готово».
