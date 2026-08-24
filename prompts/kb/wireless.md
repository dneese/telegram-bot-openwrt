# OpenWrt: Wi-Fi глибоко (VAP, гостьова, WPA3, mesh, DFS, діагностика)
Радіо: phy0 (2.4G) + phy1 (5G) на 4A; інтерфейси phy0-ap0 тощо. Тільки iwinfo (команди iw немає).

## Структура uci
wireless.radio0/radio1 = фізичні радіо (channel, htmode, country, disabled)
wireless.default_radio0 = VAP (ssid, encryption, key, network)
Новий VAP: uci set wireless.guest_wifi=wifi-iface; device=radio0; mode=ap; network='guest' — обовʼязково окрема мережа+зона!
## Гостьовий Wi-Fi повний рецепт (ізоляція):
1) network.guest=interface, proto static, ipaddr 192.168.9.1/24, + dhcp.guest=start='100' limit='50'
2) firewall: зона guest → forward to wan ACCEPT, input REJECT (крім dhcp/dns), forward to lan REJECT ← це і є ізоляція
3) VAP у цій мережі. Перевірка: uwifi клієнт пінгує 8.8.8.8 ✓, 192.168.1.1 ✗
## WPA3/сумісність:
encryption='sae-mixed' (WPA2+WPA3 одночасно) для нових; чистий sae ламає старих клієнтів.
ieee80211w='1'(optional)/'2'(required). Для IoT старих — psk2.
## Канали/hmode:
2.4G: channel 1|6|11, htmode HT20 (у забудові краще ніж HT40!)
5G: канали 36-48 (без DFS) або 52-144 (DFS!), htmode VHT80; HE80 якщо підтримує
DFS-дропи: радіо мовчить 1-10хв при radar — не панікуй, це норма; уникай DFS каналів якщо важлива стабільність.
country='UA' обовʼязково (інакше регуляторка неправильна).
## Сила сигналу:
uci set wireless.radio1.txpower='20' (dBm); вищий ≠ кращий для мобільних роумінгів.
disable_scan_offload? powersave: клієнти самі; на апараті: option disassoc_low_ack '0' для нестабільних IoT.
## Mesh/WDS:
802.11s mesh: wifi-iface mode='mesh' mesh_id=... mesh_fwding — тільки однакові чіпи!
WDS (бридж іншого роутера): mode='ap' wds='1' або sta+wds. На mipsel CPU mesh жере CPU — для 128МБ краще WDS/repeater.
## Діагностика:
iwinfo phy0-ap0 info | assoclist | scan (список клієнтів/RSSI/канали сусідів)
RSSI: >-50 чудово, -60 ок, -70 погано, <-75 розриви
logread | grep -i "deauth\|disassoc" — хто відвалюється
Повільний Wi-Fi при сильному сигналі → перевір htmode та legacy rates: uci set wireless.default_radio0.bss_isolation...
## БЕЗПЕЧНІ ПРОФІЛІ (перевірені для 4A/щільної забудови):
Профіль «Стабільність» (дефолт-рекомендація):
2.4G: channel '6' (або 1/11 за сканом), htmode 'HT20', txpower '15', encryption sae-mixed, ieee80211w '1'
5G: channel '36' (не DFS!), htmode 'VHT80', txpower '20' (максимум легальний), sae-mixed
Профіль «IoT-дружній»: окремий SSID 2.4G psk2 (без WPA3!), HT20, disassoc_low_ack '0', max_listen_interval
Профіль «Швидкість ближніх»: 5G VHT80 ch44(DFS-менш завантажений у деяких районах)+короткий dhcp lease; 2.4G вимкнути зовсім якщо всі клієнти ac/ax.
Вибір каналу 2.4 МЕТОДОЛОГІЯ: iwinfo phy0-ap0 scan | grep -E "Channel|Signal" → рахуй сусідів по 1/6/11 → бери найпорожніший; HT40 на 2.4 НЕ вмикай у місті.
5G: спершу non-DFS 36/44; якщо сусіди сидять там усі — 52+ (DFS: очікуй паузи при радарі).
## Пастки:
- Гостьова без окремої zone = ізоляції НЕМАЄ (клієнти бачать LAN)
- sae-only + старий ноут = «Wi-Fi підключено без інтернету»
- 40MHz на 2.4G в багатоквартирному = колапс швидкості всім
