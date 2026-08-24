# Продуктивність на слабкому CPU (mipsel 880МГц, 128МБ)
## Головний важіль — flow offload (software):
uci set firewall.@defaults[0].flow_offloading='1' (SW, безпечний, +30-50% throughput NAT)
hardware offloading НЕ підтримується цим чіпом (немає PPE) — не обіцяй.
Перевірка ефекту: iperf3 до/після; top (softirq падає).
## SQM vs швидкість:
cake тримає ~100-150Мбіт на цьому CPU. Канал >150Мбіт → або fq_codel простіший, або чесно: «SQM вимкнено бо канал швидший за CPU».
## RAM-дисципліна:
free: low free ≠ проблема (page cache); тривога коли available <10МБ і росте swap/zram.
zram-swap: apk add zram-swap; /etc/config/zram option size '32' — рятує від OOM-вбивств ціною CPU при свопінгу.
Злодії RAM типові: великі adblock списки (tmpfs!), tailscale, samba4, nlbwmon з довгим інтервалом комміту.
## Wi-Fi мікро-тюнинг:
powersave клієнтський — не наш; наші: disassoc_low_ack '0' для IoT; beacon_int '100' дефолт не чіпати; dtim_period 1 (дефолт).
multicast_to_unicast '1' на VAP = менше флуду для IPTV/mDNS важких мереж.
## Процесорні злодії:
top за CPU: dnsmasq при DNS-flood, uhttpd при скануванні веба, sqm/cake під навантаженням, wireguard при 100+Мбіт.
logread -f теж їсть при флуді логів — наш tg-watch має rate-limit саме тому.
## Що НЕ робити:
- compcache/swappiness маніпуляції поза zram-swap пакетом
- irqbalance (одноядерному ніколи)
- «оптимізатори» opkg-скрипти з інтернетів — тільки конкретні опції вище
## Очікування реальності (чесно власнику):
NAT routing ~300-500Мбіт SW-offload | WG ~80-120Мбіт | OpenVPN ~10-20 | cake ~120-150 | Samba USB ~8-15МБ/с
Це нормальні цифри для класу пристрою, а не «поломка».
