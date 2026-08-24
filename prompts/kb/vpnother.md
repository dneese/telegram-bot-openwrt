# OpenWrt: інші VPN на слабкому залізі (128МБ mipsel)
Правило здорового глузду: WireGuard завжди перший вибір. Решта — коли примус.

## OpenVPN
apk add openvpn-openssl (~500КБ+). CPU: openvpn-udp ~5-15Мбіт/с на цьому чіпі, tcp повільніше.
Конфіг у /etc/openvpn/*.ovpn + interface 'ovpn0'? Класика: uci не керує — покласти .conf в /etc/openvpn/, service openvpn enable.
TUN vs TAP: tun майже завжди. auth SHA256, cipher AES-128-GCM (AES-256 жере CPU марно).
Ключі easy-rsa — генеруй НЕ на роутері (повільно і секрети), тільки клієнтські .ovpn сюди.
luci-app-openvpn для UI. Лог діагностика: logread -f | grep -i ovpn

## Tailscale
apk add tailscale (~15МБ розпаковано! flash 16МБ — впритул, перевір df перед установкою; можливо тільки з USB-overlay).
userspace networking mode (tailscaled --tun=userspace-networking) — без kernel-tun, швидкість нижча, але RAM ~30-40МБ... на 128МБ з усім іншим = ризик OOM. Чесна порада: на цьому роутері краще WG.
Якщо дуже треба: tailscale up --advertise-exit-node; subnet router --advertise-routes.

## ZeroTier
~8МБ, легший за TS. zt0 через uci? Ні: zerotier-one CLI + join мережі; авторизація в ZT Central.
interface ztq... додати в zone lan (bridge) щоб бачити LAN.

## SSH-тунель як VPN-заміна (мікро-випадки):
ssh -N -L / -w tap — без зайвих пакетів, для одного порту часто достатньо autossh.

## Порівняння CPU-навантаження на mipsel 4A:
WG ≈ 100+ Мбіт | OpenVPN UDP AES-GCM ≈ 10-20 | OpenVPN CBC ≈ 5-8 | TLS-тунелі ≈ 5-15
RAM резидентні: WG ~0 | ovpnsrv ~3-5МБ | zt ~10МБ | ts ~35МБ
## Пастки:
- flash 16МБ: після apk add великого пакета перевіряй df / — переповнення = поламаний overlay
- два VPN одночасно + SQM = CPU насос; дивись top у момент проблеми
