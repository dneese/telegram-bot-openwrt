# OpenWrt: файрвол fw4 глибоко
fw4 (nftables). Конфіг /etc/config/firewall. Перегляд правил: nft list ruleset | head -60

## Модель: зони + forwarding + rules/redirects
Зона = набір інтерфейсів. lan→wan ACCEPT (типово), wan input REJECT — не ламай!
Нове правило трафіку:
uci add firewall rule; name src dest proto src_ip src_port dest_ip dest_port target(ACCEPT/REJECT/DROP)
family 'ipv4'/'ipv6'/'any'. extra: ipmask, mark, setmark.
## Redirect (port forward / DNAT):
uci add firewall redirect; name src='wan' proto='tcp udp' src_dport='8080' dest_ip='192.168.1.50' dest_port='80' target='DNAT'
Reflection (доступ зсередини по зовнішньому IP): option reflection '1', reflection_src 'internal'.
CGNAT → redirect марний (перевір WAN-адресу спершу!).
## Traffic rule vs redirect:
rule = фільтрація (ACCEPT/REJECT), redirect = проброс/NAT. Відкрити порт НА роутері = rule з dest='device'? Ні: src='wan' target='ACCEPT' dest_port='443' proto='tcp' без dest.
## DMZ-хост (все назовні на одну машину):
redirect без dest_port? fw4: окремий zone-forward? Правильно: rule src wan dest lan dest_ip X target ACCEPT + redirect family... Простіше радити specific redirects; повний DMZ через uci add redirect + option target 'SNAT'? НЕ ускладнюй: для «відкрити все» → кілька redirects по портах або VPN замість цього.
## Time-based правила (батьківський контроль):
rule + start='23:00' stop='08:00' weekdays='Mon Tue Wed Thu Fri'; через північ (start>stop) коректно. UTC vs local: fw4 бере локальний час системи (перевір date).
## MAC-фільтр Wi-Fi:
не в firewall! wireless VAP: option macfilter 'allow'|'deny' + list maclist 'AA:BB:...'
Або ізоляція по VLAN+зоні — надійніший підхід ніж MAC (спуфінг!).
## SNAT/masquerade:
per-zone option masq '1'. Кілька WAN: masq на кожній зоні.
## Пастки:
- Зміни без `uci commit firewall && /etc/init.d/firewall restart` не працюють
- input REJECT на wan зони — святе; не відкривай 22/80/443 наружу без потреби (VPN краще)
- nft помилки після ручних редагувань: fw4 check; logread | grep fw4
