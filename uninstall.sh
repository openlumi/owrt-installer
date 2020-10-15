#!/bin/sh

. /lib/functions.sh
. /lib/functions/system.sh
. /usr/share/libubox/jshn.sh

export SAVE_PARTITIONS=1

if uname -r | grep "^4.1" >/dev/null; then
    # Ok, we can proceed
    echo "Kernel check... OK"
else
    echo "Restored backup wouldn't boot without stock kernel."
    echo "Remove this check if you really sure of what you are doing!"
    exit 1
fi

if [ "$#" -ne "1" ]; then 
    echo -e "Usage:\n\t$0 <rootfs_backup.tgz>"
    exit 1
fi

if [ ! -f "$1" ]; then
    echo "$1 doesn't exist!"
    exit 1
fi

IMAGE=$1
IMAGE="$(readlink -f "$IMAGE")"

if [ ! -s $IMAGE ]; then
    echo "$IMAGE is empty! Cannot proceed"
    exit 1
fi

include /lib/upgrade

case "$IMAGE" in
    '')
        echo "Image file not found." >&2
        exit 1
        ;;
    /tmp/*) ;;
    *)
        v "Image not in /tmp, copying..."
        cp -f "$IMAGE" /tmp/lumi_stock.tgz
        IMAGE=/tmp/lumi_stock.tgz
        ;;
esac

write_stage2() {
    mv /lib/upgrade/do_stage2 /lib/upgrade/do_stage2.bak

    cat > /lib/upgrade/do_stage2 <<- EOF
#!/bin/sh

. /lib/functions.sh

include /lib/upgrade

v "Performing system downgrade..."
ubirmvol /dev/ubi0 -N rootfs
ubimkvol /dev/ubi0 -N rootfs -m
mkdir -p /mnt
mount -t ubifs ubi0:rootfs /mnt
busybox tar -zxvf $IMAGE -C /mnt/ 

v "Downgrade completed"
sleep 1

v "Rebooting system..."
umount -a
reboot -f
sleep 5
echo b 2>/dev/null >/proc/sysrq-trigger
EOF

    chmod +x /lib/upgrade/do_stage2
}

echo
echo =================================================================
echo Last chance!!! OpenWRT would be replaced with Stock OS backup. 
echo Proceed only if you really sure of what you are doing!
echo You have 15 seconds. Press Ctrl+C to cancel.
echo =================================================================
sleep 15

write_stage2

install_bin /sbin/upgraded
v "Commencing downgrade. Closing all shell sessions."

COMMAND='/lib/upgrade/do_stage2'

json_init
json_add_string prefix "$RAM_ROOT"
json_add_string path "$IMAGE"
json_add_boolean force 1
json_add_string command "$COMMAND"
json_add_object options
json_add_int save_partitions "$SAVE_PARTITIONS"
json_close_object

ubus call system sysupgrade "$(json_dump)"
