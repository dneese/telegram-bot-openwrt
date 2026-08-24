# OpenWrt: DNS/DHCP (dnsmasq) глибоко
dnsmasq керує і DNS-кешем, і DHCP. Конфіг: /etc/config/dhcp (секції dnsmasq, dhcp, host, domain).

## Базові ручки:
dhcp.@dnsmasq[0]: option noresolv '1' (ігнорувати resolvfile), list server '1.1.1.1', list server '8.8.8.8'
Кеш/паралелізм: option cachesize '1000'; allservers '1' (питає всі одночасно — швидший, більше запитів).
## Зміна DNS для КЛІЄНТІВ (типовий запит):
uci add_list dhcp.@dnsmasq[0].server='1.1.1.1'; uci delete dhcp.@dnsmasq[0].server='/mask.icu/ 207...' (спершу подивись uci show dhcp | grep server)
АБО клієнтам видавати інші DNS по DHCP: dhcp.lan.dhcp_option='6,1.1.1.1,9.9.9.9' (option 6). Перевірка з ПК: nslookup google.com 192.168.1.1
## Split-DNS (домен → свій сервер):
list server '/office.corp/10.0.0.53' — доменна суфіксація; list rebind_domain? Для локальних доменів вимкни rebind protection для них: option rebind_protection залиши, додай list rebind_domain 'corp.lan'
## DoT/DoH (шифрування DNS):
apk add https-dns-proxy (~200КБ, легкий!). Він слухає 127.0.0.1#5053×N провайдерів; dnsmasq: list server '127.0.0.1#5053'. Провайдери в /etc/config/https-dns-proxy. Стоп системного DNS-витоку: noresolv+видалити провайдерські server.
stubby важчий — на 128МБ https-dns-proxy достатньо.
## Adblock:
apk add luci-app-adblock (~місце! списки в RAM/tmpfs). Конфіг /etc/config/adblock: список ssl_sources... Режим без LuCI: adb_sources. Памʼять: великий список = +20-40МБ tmpfs — на 128МБ обережно, бери compact-списки.
Альтернатива легша: dnsmasq list address '/doubleclick.net/0.0.0.0' вручну кілька десятків записів.
## Static leases:
uci add dhcp host; name='nas'; mac='AA:BB:CC:DD:EE:FF'; ip='192.168.1.50'; leasetime='infinite'
DNS-імʼя автоматом з host.name ✓ (domain section не потрібен).
## DHCP опції (часті):
6=DNS, 3=router(шлюз), 15=domain, 42=NTP, 44=WINS, 66/67=PXE(tftp: dhcp.boot + tftp section)
Tag-based (для гостьової/VLAN): dhcp.guest.dhcp_option='6,192.168.9.1'; tag через option tag + host.tag.
## Резервування/дивини:
- lease файл: /tmp/dhcp.leases (час MAC IP hostname clientid)
- «клієнт не отримує IP»: перевір dhcp.<iface>.ignore '0', start/limit у діапазоні, logread | grep dnsmasq
- DNS витік IPv6: RA видає провайдерський DNS! network.lan.ra_flags? Простіше: dhcp.lan.ra_dns... або забрати ra_management; точково: uci set dhcp.lan.ndproxy_routing... Чесний фікс: https-dns-proxy ловить все що йде в 53 на роутері, але клієнт→зовні мимо роутера не ловиться — тоді firewall rule REJECT udp dest_port 53 src lan NOT to router_ip + redirect на себе.
