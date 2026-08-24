# Скіл: Мережа та DHCP

## Зміна LAN IP (обережно — рве связь!)
uci set network.lan.ipaddr='192.168.9.1'; uci commit network; /etc/init.d/network reload
ПОПЕРЕДЖУЙ користувача: адмінка буде на новому IP, пристрої оновлять DHCP до ~хвилини.
Перевірка: uci -c /etc/config get network.lan.ipaddr (файл) і ifstatus lan | jsonfilter -e '@["ipv4-address"][0].address' (застосовано).

## Пул DHCP
uci get dhcp.@dhcp[0].start/.limit/.leasetime ; змінити: uci set dhcp.@dhcp[0].start='100' .limit='150' ; uci commit dhcp && /etc/init.d/dnsmasq restart

## Статична аренда (резервування IP)
uci add dhcp host
uci set dhcp.@host[-1].name='імʼя' .mac='AA:BB:CC:DD:EE:FF' .ip='192.168.1.50'
uci commit dhcp && /etc/init.d/dnsmasq restart
Перевірка: grep імʼя /etc/config/dhcp

## Хто підключений зараз
cat /tmp/dhcp.leases  (формат: час MAC IP ім'я clientid)
Активні (ARP): cat /proc/net/arp | grep 0x2

## WAN протокол / PPPoE
uci show network.wan ; pppoe: uci set network.wan.proto='pppoe' .username='..' .password='..' ; commit && network restart (РВЕ СВЯЗЬ!)
Статус: ifstatus wan | jsonfilter -e '@.up' , адреса @["ipv4-address"][0].address

## Правило застосування
DNS/DHCP → dnsmasq restart; IP/протоколи → network reload|restart (тільки з попередженням).

## Зміна підмережі
При зміні ipaddr іншої підмережі (наприклад на 192.168.9.1) онови і netmask (.netmask='255.255.255.0'), та памʼятай: статичні аренди зі старої підмережі стануть невалідними — запропонуй чистку dhcp.host.
