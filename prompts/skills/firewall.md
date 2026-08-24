# Скіл: Файрвол

## Перегляд
uci show firewall | head -60 ; активні з'єднання: cat /proc/net/nf_conntrack 2>/dev/null | head -20

## Проброс порту (DNAT)
УВАГА: якщо WAN = CGNAT (100.64/10) — проброс ЗОВНІ бесполезен, попередь!
uci add firewall redirect
uci set firewall.@redirect[-1].name='web' .src='wan' .proto='tcp udp' .src_dport='8080' .dest_ip='192.168.1.50' .dest_port='80' .target='DNAT'
uci commit firewall && /etc/init.d/firewall restart
Перевірка: uci show firewall.@redirect[-1] ; nft list chain dstnat 2>/dev/null | head

## Правило блокування (приклад: заблокувати IP для LAN)
uci add firewall rule
uci set firewall.@rule[-1].name='block-x' .src='lan' .dest='wan' .dest_ip='1.2.3.4' .target='REJECT'
uci commit firewall && /etc/init.d/firewall restart

## Відкрити порт НА РОУТЕРІ (input)
uci set firewall.@rule[-1]=rule ... .src='wan' .dest_port='443' .proto='tcp' .target='ACCEPT'

## Зони
uci show firewall | grep -E "zone|forwarding"
Стандарт: lan→wan ACCEPT, wan input REJECT — не вимикай input на wan НІКОЛИ.
