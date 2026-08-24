# OpenWrt: мережа (DSA, VLAN, мости, маршрутизація, multi-WAN)
Платформа: ImmortalWrt 24/25.x, DSA (замість swconfig!), busybox ash, apk.
Пристрій-орієнтир: Mi Router 4A Gigabit — 128МБ RAM, mipsel, 16MB flash, 2 порти LAN+WAN.

## Концепція DSA
Порти тепер справжні Linux-інтерфейси: lan1 lan2 wan (не eth0.1!). Бридж = device у /etc/config/network.
Перегляд: ip link; bridge link; uci show network
## VLAN'и (DSA)
Створити VLAN-бридж з тегуванням:
uci set network.br_vlan=device && uci set network.br_vlan.name='br-vlan20'
uci set network.br_vlan.type='bridge' && uci add_list network.br_vlan.devices='lan1'
uci set network.@device[-1].ports='' # не потрібен окремо
# VLAN-фільтр через bridge vid на інтерфейсі:
ip link add link lan1 name lan1.20 type vlan id 20   # тимчасово
Постійно — network.<name>=interface з device 'lan1.20' + br_vlan device list 'lan1.20'.
Перевірка: bridge vlan show
## Новий інтерфейс у VLAN:
uci set network.iot=interface; uci set network.iot.device='br-lan.20'; uci set network.iot.proto='static'
uci set network.iot.ipaddr='192.168.20.1'; uci set network.iot.netmask='255.255.255.0'
## Статичний маршрут:
uci add_network route; uci set network.@route[-1].interface='lan'; uci set network.@route[-1].target='10.10.0.0/16'; uci set network.@route[-1].gateway='192.168.1.254'
## Multi-WAN без mwan3 (легкий спосіб):
Дві зони wan/wanb + metric: uci set network.wan.metric='10'; network.wanb.proto='dhcp', metric 20 → failover автоматичний (default route за metric). LB без mwan3 не робити.
mwan3 (справжній PBR): apk add mwan3 luci-app-mwan3 — але ~1МБ і складно; на 128МБ ок, конфіг /etc/config/mwan3 (політики balanced/sticky, rule по src_ip).
## Перевірка після будь-якої зміни мережі:
ip addr show br-lan; ip route; ping -c1 192.168.1.1
НЕ роби network restart без потреби — рве звʼязок. Точково: ifup <iface>.
## Пастки:
- WAN від ISP часто CGNAT (100.64/10) — проброси марні, перевір: ip addr show pppoe-wan | grep inet
- PPPoE MTU 1492/1480: uci set network.wan.mtu='1492'
- MAC-байндінг ISP: uci set network.wan.macaddr='XX:XX:...'
