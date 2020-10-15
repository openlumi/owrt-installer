# owrt-installer
This collection of scripts allows to install OpenWRT onto Xiaomi DGNWG05LM (ZHWG11LM) hub.

## Caution!
Every unit has it's own unique token. It can't be regenerated. You won't be able to return to stock firmware and use MiHome if you wouldn't make a backup of it.
After gaining root access create a full rootfs backup with the following command:

```
tar -cvpzf /tmp/lumi_stock.tar.gz -C / --exclude='./tmp/*' --exclude='./dev/*' --exclude='./run/*' --exclude='./proc/*' --exclude='./sys/*' .
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

## Steps to revert to stock
1. Log into box as root.
2. Download and extract stock kernel. You might use your own.
```
wget -o /root/stock.tar.gz https://github.com/openlumi/owrt-installer/releases/download/stock/stock_kernel.tar.gz
tar -C / -zxvf /root/stock.tar.gz
```
3. Download uninstall script.
```
wget -o /root/uninstall.sh https://raw.githubusercontent.com/openlumi/owrt-installer/main/uninstall.sh
chmod +x /root/uninstall.sh
```
4. Upload your `lumi_stock.tar.gz` from your PC to `/root/` folder of your box. Make sure you have enough space for it.
5. Downgrade kernel.
```
/root/flash_kernel.sh /root/stock-lumi.dtb /root/stock-zImage
```
6. Reset your WiFi settings, they would probably be obsolete after kernel downgrading.
```
rm /etc/config/wireless
```
7. **REBOOT**
8. Log into your box using it's AP or within UART.
9. Make sure you have all needed files (`/root/uninstall.sh` and `/root/lumi_stock.tar.gz`) in place.
10. Run uninstall script.
```
/root/uninstall.sh /root/lumi_stock.tar.gz
```
After reboot you should have a stock OS running. If you got a brick, use mfgtools method.

---
# owrt-installer
Коллекция скриптов для автоматической установки OpenWRT на хаб Xiaomi DGNWG05LM (ZHWG11LM).

## Внимание!
Каждый хаб имеет свой уникальный идентификатор в облаке MiHome. Его невозможно восстановить. Вы не сможете вернуться на стоковую прошивку и продолжить использовать MiHome если не сделаете резервную копию.
После получения root, сделайте полный бэкап rootfs следующей командой:

```
tar -cvpzf /tmp/lumi_stock.tar.gz -C / --exclude='./tmp/*' --exclude='./dev/*' --exclude='./run/*' --exclude='./proc/*' --exclude='./sys/*' .
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

## Откат на стоковую прошивку
1. Зайдите на устройство с правами root.
2. Скачайте и распакуйте стоковое ядро. Может использовать свою копию, если сделали бэкап.
```
wget -o /root/stock.tar.gz https://github.com/openlumi/owrt-installer/releases/download/stock/stock_kernel.tar.gz
tar -C / -zxvf /root/stock.tar.gz
```
3. Скачайте скрипт uninstall
```
wget -o /root/uninstall.sh https://raw.githubusercontent.com/openlumi/owrt-installer/main/uninstall.sh
chmod +x /root/uninstall.sh
```
4. Загрузите ваш бэкап `lumi_stock.tar.gz` с вашего компьютера в папку  `/root/` на вашем устройстве. Предварительно убедитесь что места достаточно.
5. Даунгрейдните ядро до стокового.
```
/root/flash_kernel.sh /root/stock-lumi.dtb /root/stock-zImage
```
6. Сбросьте ваши настройки WiFi, вероятнее всего со стоковым ядром они будут бесполезны.
```
rm /etc/config/wireless
```
7. **ПЕРЕЗАГРУЗИТЕ ХАБ**
8. Подключитесь к хабу через точку доступа или с помощью UART.
9. Убедитесь что все нужные файлы (`/root/uninstall.sh` и `/root/lumi_stock.tar.gz`) на месте и правильных размеров.
10. Запустите скрипт uninstall.
```
/root/uninstall.sh /root/lumi_stock.tar.gz
```
После перезагрузки вы получите стоковую прошивку на момент бэкапа. Если на выходе получился кирпич, попробуйте прошивку с помощью mfgtools.