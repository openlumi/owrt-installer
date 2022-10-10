#!/bin/bash

VERSION=${VERSION:-19.07.10}

SYSUP_URL=https://openlumi.github.io/releases/${VERSION}/targets/imx6/generic/openlumi-${VERSION}-imx6-lumi-squashfs-sysupgrade.bin
DTB_URL=https://openlumi.github.io/releases/${VERSION}/targets/imx6/generic/openlumi-${VERSION}-imx6-imx6ull-xiaomi-lumi.dtb
UTILS_HOST=raw.githubusercontent.com
UTILS_URL=/openlumi/owrt-installer/main/curl
UPDATE_URL=/openlumi/owrt-installer/main/update.sh
PKG=/tmp/m.tar
KERNEL=kernel
DTB=lumi.dtb
SQUASHFS=rootfs.squashfs

w_get() {
    echo -e "GET $2 HTTP/1.0\nHost: $1\n" | openssl s_client -quiet -connect $1:443 -servername $1 2>/dev/null | sed '1,/^\r$/d' > $3
}

echo =================================================================
echo OpenWRT automatic installer
echo =================================================================

# Sanity checks first
if [ ! -d "/lumi" ]; then
    echo
    echo Only STOCK firmware supported. Please try another upgrade path.
    exit -1
fi

#if lsmod | grep 8189es >/dev/null; then
#    echo
#    echo WiFi module 8189es is not supported by OpenWRT yet.
#    exit -1
#fi

echo
echo Updating time...
ntpdate pool.ntp.org

echo
echo Downloading curl...
WORKDIR=$(mktemp -d)
w_get $UTILS_HOST $UTILS_URL $WORKDIR/curl
chmod +x $WORKDIR/curl

echo
echo Downloading DTB...
$WORKDIR/curl --insecure -L -o $WORKDIR/$DTB $DTB_URL
if [ ! -s $WORKDIR/$DTB ]; then
    echo Download failed, please check available space and try again.
    exit -1
fi

echo
echo Downloading SysUpgrade package...
$WORKDIR/curl --insecure -L -o $PKG $SYSUP_URL
if ! tar -xvf $PKG -C $WORKDIR; then
    echo Unpacking failed, please check available space and try again.
    exit -1
fi
rm $PKG
mv $WORKDIR/sysupgrade-*/kernel $WORKDIR/$KERNEL
mv $WORKDIR/sysupgrade-*/root $WORKDIR/$SQUASHFS
rm -rf $WORKDIR/sysupgrade-*

echo
echo Downloading upgrade script...
$WORKDIR/curl --insecure -L -o $WORKDIR/update.sh https://$UTILS_HOST$UPDATE_URL
if [ ! -s $WORKDIR/update.sh ]; then
    echo Download failed, please check available space and try again.
    exit -1
fi
chmod +x $WORKDIR/update.sh

echo
echo =================================================================
echo Last chance!!! Stock OS would be replaced with OpenWRT. 
echo You have 15 seconds. Press Ctrl+C to cancel.
echo =================================================================
sleep 15

setsid $WORKDIR/update.sh $WORKDIR/$DTB $WORKDIR/$KERNEL $WORKDIR/$SQUASHFS >/dev/ttymxc0 2>&1 < /dev/null &
