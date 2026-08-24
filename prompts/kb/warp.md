# Cloudflare WARP через WireGuard (приватний вихід, обхід блокувань по IP)
WARP = WireGuard-тунель до Cloudflare (endpoint engage.cloudflareclient.com:2408).
Що дає: шифрування трафіку, інший вихідний IP (країни CF), приховування від провайдера.
Чого НЕ дає: проброс портів всередину, статичний IP, вибір країни (в free).

## Крок 1 — отримати профіль WARP (один раз, НЕ на роутері):
На ПК: завантажити wgcf (github.com/ViRb3/wgcf, бінарник під ОС);
  ./wgcf register --accept-tos && ./wgcf generate → wgcf-profile.conf
У конфізі будуть: PrivateKey, Address 172.16.0.2/32, DNS 1.1.1.1, PublicKey Cloudflare, Endpoint.
Альтернатива без ПК: застосунок 1.1.1.1 не експортує ключі — тільки wgcf або готовий конфіг від власника.
## Крок 2 — роутер (бот робить САМ з наданого профілю):
uci set network.warp=interface; proto='wireguard'; private_key='<з профілю>'
uci add_list network.warp.addresses='172.16.0.2/32'; uci set network.warp.mtu='1280'
uci add network wireguard_warp; uci set network.@wireguard_warp[-1]=wireguard_warp
uci set network.@wireguard_warp[-1].public_key='<CF PublicKey=bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=>'
uci set network.@wireguard_warp[-1].endpoint_host='engage.cloudflareclient.com'
uci set network.@wireguard_warp[-1].endpoint_port='2408'; allowed_ips='0.0.0.0/0' ::/0
persistent_keepalive='25'; route_allowed_ips='0' (щоб НЕ забрати дефолт-маршрут одразу!)
uci commit network && ifup warp && sleep 3 && wg show warp (handshake?)
## Крок 3 — файрвол:
uci add firewall zone; name 'warp'; input REJECT output ACCEPT forward REJECT; masq='1'; network 'warp'
forwarding lan→warp ACCEPT (додаємо ТІЛЬКО коли вирішено режим нижче); rule src wan udp 2408 не потрібен (вихідний тунель).
## Крок 4 — режими використання:
A) ВСЕ через WARP (exit-node): route_allowed_ips='1' АБО default route metric нижче wan. ⚠️ якщо тунель ляже — інтернет «зникне»: killswitch = якраз ця поведінка, попереджай!
B) Тільки вибрані пристрої (PBR): route_allowed_ips='0'; для хоста X: правило маршруту ip rule add from <IP> table warp + ip route add default dev warp table warp (persist через hotplug/rc.local або mwan3). Простіше для одного хоста: окремий SSID/VLAN з forwarding у warp-зону.
C) Лише DNS через WARP: addresses залишити, allowed_ips='172.16.0.1/32' і dhcp_option 6 = 172.16.0.1? (WARP-DNS всередині тунелю) — тонко, рідко потрібно.
## Перевірка:
curl --interface warp https://www.cloudflare.com/cdn-cgi/trace | grep -E "ip=|warp="
(поле warp=on ✓, ip=CF-адреса)
ping 172.16.0.1 всередині тунелю; швидкість: очікуй 30-80Мбіт на цьому CPU.
## Пастки:
- MTU! 1420 часто фрагментується через PPPoE → став 1280 (надійно), трохи повільніше
- allowed_ips 0.0.0.0/0 з route_allowed_ips=1 ВІДРАЗУ ріже твій SSH до роутера ззовні — роби з LAN
- час від часу CF міняє PublicKey рідко але перевір актуальний у своєму wgcf-конфізі
- квоти: WARP free без ліміту трафіку, але «підозріла» активність може тимчасово банити акаунт
