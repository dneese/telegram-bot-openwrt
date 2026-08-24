# Zaborona.help — безкоштовний UA VPN для заблокованих ресурсів (vk.com тощо)
Роздільний тунель: ЧЕРЕЗ VPN йде ТІЛЬКИ трафік до цільових ресурсів, решта — напряму на повній швидкості.
Реєстрація НЕ потрібна: сертифікати спільні публічні. Сайт: zaborona.help

## Рецепт для роутера (OpenVPN):
1) Місце: apk add openvpn-openssl (~500КБ) — спершу df /
2) Сертифікати:
   mkdir -p /etc/openvpn/zaborona && cd /etc/openvpn/zaborona
   for F in ca.crt zaborona-help.crt zaborona-help.key; do curl -fsSL -O "https://zaborona.help/$F"; done
3) Конфіг /etc/openvpn/zaborona.conf:
client
dev tun
proto tcp
remote srv0.vpn.zaborona.help 1194
resolv-retry infinite
nobind
ca ca.crt
cert zaborona-help.crt
key zaborona-help.key
cipher AES-128-CBC
auth SHA1
verb 3
(НЕ додавай route-nopull — пушнуті маршрути і є розділенням!)
Сервери-альтернативи: srv0.vpn.zaboronahelp.pp.ua | .ovh; порт 1196; великий список маршрутів: srv0bigroutes... 1200.
4) Автозапуск uci-інстансом:
uci set openvpn.zaborona=openvpn; uci set openvpn.zaborona.enabled='1'
uci set openvpn.zaborona.config='/etc/openvpn/zaborona.conf'; uci commit openvpn
/etc/init.d/openvpn enable && /etc/init.d/openvpn restart
5) DNS ОБОВ'ЯЗКОВО (без цього обходження не працює — сервіс мапить домени через свої DNS!):
Варіант А (всі клієнти): uci add_list dhcp.lan.dhcp_option='6,208.67.222.222,208.67.220.220' && uci commit dhcp && /etc/init.d/dnsmasq restart
Варіант Б (точково на хост): dhcp host секція з власним dhcp_option.
6) Перевірка:
nslookup vk.com 208.67.222.222 → має віддати адресу з мережі VK (87.240.x.x тощо), не 127.0.0.1!
traceroute <та адреса> → перший хоп у тунелі (10.х або IP zaborona)
ping vk.com з роутера ✓ = готово; клієнтам перезапустити wifi/lease для нового DNS.

## Пастки:
- Локальні блок-списки (adblock/address=/0.0.0.0 для vk у dnsmasq) ПЕРЕМАГАЮТЬ: прибери запис якщо є
- IPv6 клієнтів може обходити тунель → тимчасово вимкнути RA або фільтрувати v6 до цілей
- TCP 1194 стабільніший за UDP при поганому каналі; CPU mipsel тягне AES-128 легко бо трафіку мало
