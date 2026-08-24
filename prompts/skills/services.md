# Скіл: Пакети та сервіси

## Пакети (тільки apk!)
Пошук: apk search -X ключове-слово | head
Встановити: apk add ім'я ; видалити: apk del ім'я
Що стоїть: apk list --installed --no-network | head -40

## Сервіси
Список: ls /etc/init.d/
Керування: /etc/init.d/SVC start|stop|restart|reload
Автозапуск: /etc/init.d/SVC enable && SVC enabled && echo on

## Корисні пакети для домашнього роутера
ddns-scripts + luci-app-ddns   — динамічний DNS (у CGNAT марний, але для IPv6/VPN ок)
https-dns-proxy                — DNS over HTTPS (див. скіл dns.md)
adblock + luci-app-adblock     — блокування реклами (див. скіл dns.md)
sqm-scripts + luci-app-sqm     — QoS/боротьба з буфербloatом
nlbwmon                        — трафік по кожному хосту (хто качає)
miniupnpd                      — UPnP для ігор/консолей
etherwake                      — Wake-on-LAN

## SQM (пристрібує лаги в іграх/дзвінках при завантаженні каналу)
apk add sqm-scripts luci-app-sqm
uci set sqm.@queue[0]=queue; uci set sqm.@queue[0].enabled='1' .interface='$(ip route | awk "/default/{print \$5;exit}")' .download='90000' .upload='45000'
Числа = ~85-90% реальної ширми каналу (kbps). uci commit sqm && /etc/init.d/sqm restart

## nlbwmon — хто скільки з'їв
apk add nlbwmon luci-app-nlbwmon && /etc/init.d/nlbwmon start
Дані: nlbwctl -c csv 2>/dev/null | head -20 (перші дні копляться)
