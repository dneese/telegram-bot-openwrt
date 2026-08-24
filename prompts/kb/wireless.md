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
## 5 ГГц: КЛІЄНТИ ВІДПАДАЮТЬ САМІ / ПРОПАДАЄ ЗВʼЯЗОК — причини і стабільний профіль
Діагностика спершу: logread | grep -iE "deauth|disassoc|sta.*kick|radar|dfs" | tail -20;
iwinfo phy1-ap0 assoclist (RSSI клієнтів); dmesg | grep -iE "wifi|mt76" (firmware asserts!)
### Причина 1: DFS-канал (найчастіше!) — радіо мовчить при кожному «радарі»
Симптом: всі клиенти падають РАЗОМ, періодично, радіо повертається через 1-10 хв.
Фікс: канал БЕЗ DFS: uci set wireless.radio1.channel='36' (або 44); commit wireless && wifi reload
Перевірка що канал не DFS: iwinfo phy1 info (канали 52+ = DFS).
### Причина 2: disassoc_low_ack — роутер сам кикає слабких/далеких/IoT
hostapd бачить «клієнт не підтверджує бикони» → кік. Симптом: один клієнт регулярно re-connect.
Фікс: uci set wireless.default_radio1.disassoc_low_ack='0' (+ те саме на 2.4 для IoT)
### Причина 3: max_inactivity — сонні клієнти (телефони у кишені) викидаються за 30с тиші
Фікс: uci set wireless.default_radio1.max_inactivity='60'; skip_inactivity_poll '0'
### Причина 4: крива country → неправильна регуляторка (потужність/канали)
uci set wireless.radio1.country='UA'; перевір фактичну потужність iwinfo phy1 info (Tx-Power)
### Причина 5: драйверні фірмварі-crash mt76 (наш чіп 5G = MT7613)
Симптом: радіо зникає до wifi reload, dmesg має "fw assert/assert failed".
Лікування: свіжа прошивка ImmortalWrt (mt76 оновлюють), НЕ VHT160 (цей чіп і не вміє), при повторах — wifi schedule на ніч як тимчасовий костыль.
### Причина 6: липкий клієнт на краю сигналу (стікійність)
RSSI <-72 дБм = клієнт тримається за мертвий сигнал замість 2.4G.
Фікс-мʼякий: зменшити txpower 5G ('16') → клієнти самі мігрують ближче/на 2.4.
Фікс-жорсткий: окремий SSID тільки 5G і вручну розсадити.
802.11k/v (роумінг-підказки): вимагає wpad-openssl (замість basic) + option bss_transition '1', ieee80211r '0'.
### Причина 7: перешкоди/ширина
VHT80 на завантаженому ефірі → спробуй HT40+ (стабільніше, трохи повільніше);
сусідський AP на тому ж каналі з сильним сигналом → змінити канал (36↔44↔149 якщо без DFS).
### СТАБІЛЬНИЙ ПРОФІЛЬ 5ГГц (застосовуй як дефолт лікування):
uci set wireless.radio1.channel='36'; uci set wireless.radio1.htmode='VHT80'
uci set wireless.default_radio1.disassoc_low_ack='0'; uci set wireless.default_radio1.max_inactivity='60'
uci set wireless.radio1.country='UA'; uci set wireless.radio1.txpower='20'
uci commit wireless && wifi reload   # ⚠️ Wi-Fi мигне на ~10с — попередь!
Критерій успіху: 24год без deauth у логу при RSSI >-65.

## Пастки:
- Гостьова без окремої zone = ізоляції НЕМАЄ (клієнти бачать LAN)
- sae-only + старий ноут = «Wi-Fi підключено без інтернету»
- 40MHz на 2.4G в багатоквартирному = колапс швидкості всім
