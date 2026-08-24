# Скіл: Wi-Fi

## Гостьова мережа (повний набір)
1) Точка доступу:
   uci add wireless wifi-iface
   uci set wireless.@wifi-iface[-1].device='radio0' .mode='ap' .network='guest' .ssid='Guest' .encryption='psk2' .key='ПАРОЛЬ' .isolate='1'
2) Мережа:
   uci set network.guest=interface; uci set network.guest.proto='static'; uci set network.guest.device='br-guest'; uci set network.guest.ipaddr='192.168.9.1'; uci set network.guest.netmask='255.255.255.0'
3) DHCP для гостей: uci set dhcp.guest=dhcp; uci set dhcp.guest.interface='guest'; uci set dhcp.guest.start='100'; uci set dhcp.guest.limit='50'; uci set dhcp.guest.leasetime='1h'
4) Файрвол-зона (ізоляція від LAN):
   uci add firewall zone; uci set firewall.@zone[-1].name='guest' .network='guest' .input='REJECT' .output='ACCEPT' .forward='REJECT'
   дозволити гостям інтернет: uci add firewall forwarding; uci set firewall.@forwarding[-1].src='guest' .dest='wan'
5) Застосувати: uci commit wireless network dhcp firewall && wifi reload && /etc/init.d/network reload && /etc/init.d/dnsmasq restart && /etc/init.d/firewall restart
Перевірка: iwinfo phy0-ap0 info (дивись SSID), ubus call network.interface.guest status

## Канал/потужність/приховування
uci get wireless.radio0.channel ; змінити: uci set wireless.radio0.channel='11' .txpower='20' .htmode='HT20'
Приховати SSID: uci set wireless.@wifi-iface[0].hidden='1'
Застосувати: uci commit wireless && wifi reload
Попередження: клієнти перепідключаться (~10с).

## Клієнти
iwinfo phy0-ap0 assoclist → MAC, сигнал dBm, SNR, TX/RX MBit/s. Слабкий сигнал = < -70 dBm.

## Вимкнути/увімкнути WiFi
Вимкнути: uci set wireless.radio0.disabled='1'; commit+reload. Увімкнути: disabled='0'.
