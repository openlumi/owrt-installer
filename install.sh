#!/bin/bash

SYSUP_URL=https://github.com/devbis/xiaomi-gateway-openwrt/releases/download/0.1.0rc4/openwrt-imx6-lumi-ubifs-sysupgrade-rc4.tar
UTILS_HOST=raw.githubusercontent.com
UTILS_URL=/openlumi/owrt-installer/rc4/curl
UPDATE_URL=/openlumi/owrt-installer/rc4/update.sh
PKG=/tmp/m.tar
UBIFS=rootfs.ubifs

w_get() {
    echo -e "GET $2 HTTP/1.0\nHost: $1\n" | openssl s_client -quiet -connect $1:443 2>/dev/null | sed '1,/^\r$/d' > $3
}

echo =================================================================
echo OpenWRT automatic installer
echo =================================================================

echo
echo Updating time...
ntpdate pool.ntp.org

echo
echo Downloading curl...
WORKDIR=$(mktemp -d)
w_get $UTILS_HOST $UTILS_URL $WORKDIR/curl
chmod +x $WORKDIR/curl

echo
echo Downloading SysUpgrade package...
$WORKDIR/curl -L -o $PKG $SYSUP_URL
if ! tar -xvf $PKG -C $WORKDIR; then
    echo Unpacking failed, please check available space and try again.
    exit -1
fi
rm $PKG
cp -v $WORKDIR/sysupgrade-*/root /$UBIFS

echo
echo Downloading upgrade script...
$WORKDIR/curl -L -o /update.sh https://$UTILS_HOST$UPDATE_URL
chmod +x /update.sh
rm -rf $WORKDIR

echo
echo =================================================================
echo Last chance!!! Stock OS would be replaced with OpenWRT. 
echo You have 15 seconds. Press Ctrl+C to cancel.
echo =================================================================
sleep 15

setsid /update.sh /$UBIFS >/dev/ttymxc0 2>&1 < /dev/null &
