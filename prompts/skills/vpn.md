# Скіл: WireGuard VPN

## Встановлення
apk add wireguard-tools luci-proto-wireguard kmod-wireguard

## Сервер на роутері (доступ до дому звідкись)
1) Ключі: WG_PRIV=$(wg genkey); WG_PUB=$(echo "$WG_PRIV" | wg pubkey); echo "$WG_PRIV" > /etc/wireguard.key; chmod 600 /etc/wireguard.key
2) Інтерфейс:
   uci set network.wg0=interface; uci set network.wg0.proto='wireguard'; uci set network.wg0.private_key="$WG_PRIV"; uci set network.wg0.listen_port='51820'; uci add_list network.wg0.addresses='10.9.0.1/24'
3) Пір (телефон/ноут): секція
   uci add firewall rule ... — спершу зона:
   uci add firewall zone; uci set firewall.@zone[-1].name='wg' .network='wg0' .input='ACCEPT' .output='ACCEPT' .forward='ACCEPT'
   uci add firewall forwarding; uci set firewall.@forwarding[-1].src='lan' .dest='wg'  (і назад для доступу в LAN)
4) Відкрити порт: правило input wan udp 51820 ACCEPT (див. скіл firewall.md) — але у CGNAT зовні не спрацює!
5) uci commit network firewall && /etc/init.d/network restart (РВЕ СВЯЗЬ ~30с — попередь!)
Перевірка: wg show ; ping 10.9.0.1 з клієнта

## Клієнтські конфіги для користувача
Генеруй текст .conf: [Interface] PrivateKey=<згенерений>, Address=10.9.0.2/24, DNS=192.168.1.2; [Peer] PublicKey=<серверний pub>, Endpoint=<ПУБЛІЧНИЙ IP або домен>:51820, AllowedIPs=0.0.0.0/0
Публічний IP у CGNAT → потрібен VPS-хоп (див. recipes).

## Безпека
Приватні ключі не показуй у SAY повністю — тільки перші символи і шлях до файлу.
