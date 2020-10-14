# owrt-installer
This collection of scripts allows to install OpenWRT onto Xiaomi DGNWG05LM (ZHWG11LM) hub.

## Caution!
Every unit has it's own unique token. It can't be regenerated. You won't be able to return to stock firmware and use MiHome if you wouldn't make a backup of it.
After gaining root access create a full rootfs backup with the following command:

```
tar -cvpzf /tmp/lumi_stock.tar.gz -C / --exclude='./tmp/*' --exclude='./proc/*' --exclude='./sys/*' .
```
And copy the resulted `/tmp/lumi_stock.tar.gz` to your PC!

## Steps to install
1. Gain root. Usually requires soldering.
2. Start dropbear (`/etc/init.d/dropbear start`)
3. Log into box using ssh (using password you've set while rooting)
4. Issue the following command in the command line.
```
echo -e "GET /openlumi/owrt-installer/main/install.sh HTTP/1.0\nHost: raw.githubusercontent.com\n" | openssl s_client -quiet -connect raw.githubusercontent.com:443 2>/dev/null | sed '1,/^\r$/d' | bash
```

---
# owrt-installer
Коллекция скриптов для автоматической установки OpenWRT на хаб Xiaomi DGNWG05LM (ZHWG11LM).

## Внимание!
Каждый хаб имеет свой уникальный идентификатор в облаке MiHome. Его невозможно восстановить. Вы не сможете вернуться на стоковую прошивку и продолжить использовать MiHome если не сделаете резервную копию.
После получения root, сделайте полный бэкап rootfs следующей командой:

```
tar -cvpzf /tmp/lumi_stock.tar.gz -C / --exclude='./tmp/*' --exclude='./proc/*' --exclude='./sys/*' .
```
И скопируйте полученный файл `/tmp/lumi_stock.tar.gz` на свой компьютер!

## Установка
1. Получите root. Обычно требуется пайка.
2. Запустите dropbear (`/etc/init.d/dropbear start`)
3. Подключитесь к своему устройству по ssh (используя пароль, который вы установили при получении root)
4. Выполните в консоли следующую команду.
```
echo -e "GET /openlumi/owrt-installer/main/install.sh HTTP/1.0\nHost: raw.githubusercontent.com\n" | openssl s_client -quiet -connect raw.githubusercontent.com:443 2>/dev/null | sed '1,/^\r$/d' | bash
```
