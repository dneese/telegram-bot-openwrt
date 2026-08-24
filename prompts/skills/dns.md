# Скіл: DNS

## ТРИ РІЗНІ РЕЧІ — уточни при потребі:
1) DNS для КЛІЄНТІВ мережі (що видає роутер пристроям):
   uci add_list dhcp.@dnsmasq[0].server='8.8.8.8'
   uci add_list dhcp.@dnsmasq[0].server='8.8.4.4'
   uci commit dhcp && /etc/init.d/dnsmasq restart
2) DNS для САМОГО роутера:
   uci set network.wan.dns='8.8.8.8 8.8.4.4' ; uci commit network && ifup wan
3) Апстрими, отримані від провайдера (read-only):
   ifstatus wan | jsonfilter -e '@["dns-server"][*]'

## Перевірка
Що видається клієнтам: uci show dhcp.@dnsmasq[0]
Реальний резолв: nslookup google.com 127.0.0.1

## DoH (шифрований DNS)
apk add https-dns-proxy luci-app-https-dns-proxy
/etc/init.d/https-dns-proxy enable && /etc/init.d/https-dns-proxy start
dnsmasq автоматично почне слати запити через нього (127.0.0.1#5053).
Перевірка: logread | grep https-dns-proxy | tail -5

## Adblock (блокування реклами на всіх пристроях)
apk add adblock luci-app-adblock
uci set adblock.global.adb_enabled='1'; uci commit adblock
/etc/init.d/adblock restart
Перевірка: /etc/init.d/adblock status ; uci get adblock.global.adb_overall_count

## Правило
dnsmasq restart НЕ рве связь; network restart для DNS НЕ потрібен.
