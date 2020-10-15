#!/bin/sh

. /lib/functions.sh
. /lib/functions/system.sh
. /usr/share/libubox/jshn.sh

export SAVE_PARTITIONS=1

if [ "$#" -ne "3" ]; then 
    echo "Usage:\t$0 <dtb> <kernel> <rootfs>"
    exit 1
fi

if [ ! -f "$1" ]; then
    echo "$1 doesn't exist!"
    exit 1
fi

if [ ! -f "$2" ]; then
    echo "$2 doesn't exist!"
    exit 1
fi

if [ ! -f "$3" ]; then
    echo "$3 doesn't exist!"
    exit 1
fi

DTB=$1
KERNEL=$2
IMAGE=$3
IMAGE="$(readlink -f "$IMAGE")"

if [ ! -s $DTB ]; then
    echo "$DTB is empty! Cannot proceed"
    exit 1
fi

if [ ! -s $KERNEL ]; then
    echo "$KERNEL is empty! Cannot proceed"
    exit 1
fi

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
mkdir /mnt
mount -t ubifs ubi0:rootfs /mnt
tar -zxvf $IMAGE -C /mnt/ 

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

v "Writing Kernel..."
flash_erase /dev/mtd1 0 0
nandwrite -p /dev/mtd1 -p $KERNEL

v "Writing DTB..."
flash_erase /dev/mtd2 0 0
nandwrite -p /dev/mtd2 -p $DTB

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
