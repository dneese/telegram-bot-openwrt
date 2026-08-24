# Безпека та обслуговування прошивки (харденінг, оновлення, бекапи)
## Харденінг доступу:
1) Dropbear: тільки ключі. uci set dropbear.@dropbear[0].PasswordAuth='off'; RootPasswordAuth='off'; Port '2222'? (зміна порту = шум-захист, не безпека). Ключ клієнта: його pubkey → /etc/dropbear/authorized_keys (один рядок=один ключ).
2) LuCI: https через uhttpd (сертифікат самопідписаний ок для LAN); доступ тільки з lan зони (не відкривати на wan НІКОЛИ).
3) Файрвол: перевір що wan input REJECT; заборона ping ззовні = default (icmp у nft chain input wan дозволений echo-request? fw4 блокує крім needed).
4) Оновлення прошивки: sysupgrade БЕЗ збереження конфіга при стрибку мажорних версій! Порядок: /sbin/sysupgrade --help; бекап списку пакетів: apk info | sort > /tmp/pkgs.txt + tar czf /tmp/cfg.tar.gz /etc/config /etc/tg-bot → ЗАБРАТИ на ПК/хмару → wget firmware → sysupgrade -v /tmp/fw.bin (-n = без конфіга). Перевірка образу: sha256sum проти сайту!
5) Авто-ребут щотижня? Спірно; краще моніторинг (наш tg-analyze).
## Бекапи (що і як):
Конфіги: /etc/config/* (+ наш /etc/tg-bot/ai/*.md знання!). Команда повного бекапу на ПК: tar czf - -C / etc/config etc/tg-bot | ssh pc 'cat > rtr-backup.tar.gz' — наш бот уже вміє /backup файлом у чат.
Відновлення: розпакувати назад + restart сервісів; або /rollback для останніх uci-дій.
Секрети в бекапах: паролі wifi, ключі VPN — зберігати поза роутером обережно (файл маскувати).
## Міні-чеклист гостьової мережі (безпека гостей):
окрема subnet ✓ зона guest input REJECT forward→lan REJECT ✓ dhcp діапазон ✓ ізоляція client_isolation на VAP? wireless VAP option isolate '1' — клієнти між собою теж не бачать ✓
## Виявлення компрометації (рідко але):
невідомі cron: crontab -l; незнайомі процеси: ps w | grep -v "\[" ; нові authorized_keys; вихідні конекти дивно: netstat -tunp | head (busybox: netstat -tan)
## Пастки:
- sysupgrade -n стирає ВСЕ включно з нашим ботом → після апгрейду повторний install.sh one-liner
- «безпечний» конфіг-бекап LuCI (.tar.gz через UI) НЕ містить встановлених пакетів
- ключі dropbear тип ed25519; RSA 2048 старіше теж ок, dsa — ніколи
