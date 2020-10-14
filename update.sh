#!/bin/bash

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

DTB_FILE="$1"
KERNEL_FILE="$2"
UPDATE_FILE="$3"

if [ ! -s $DTB_FILE ]; then
    echo "$DTB_FILE is empty! Cannot proceed"
    exit 1
fi

if [ ! -s $KERNEL_FILE ]; then
    echo "$KERNEL_FILE is empty! Cannot proceed"
    exit 1
fi

if [ ! -s $UPDATE_FILE ]; then
    echo "$UPDATE_FILE is empty! Cannot proceed"
    exit 1
fi

RAM_ROOT=/mnt/root
OLD_ROOT=/old-root

UBI_FILENAME=rootfs.ubifs
LUMI_FILENAME=lumi.tar.gz


kill_remaining() { # [ <signal> [ <loop> ] ]
    local loop_limit=10

    local sig="${1:-TERM}"
    local loop="${2:-0}"
    local run=true
    local stat
    local proc_ppid=$(cut -d' ' -f4  /proc/$$/stat)

    echo -n "Sending $sig to remaining processes ... "

	while $run; do
		run=false
		for stat in /proc/[0-9]*/stat; do
			[ -f "$stat" ] || continue
			echo $stat

			local pid name state ppid rest
			read pid name state ppid rest < $stat
			name="${name#(}"; name="${name%)}"

            [ "$name" = "getty" ] && continue

            echo "my pid $pid $name $proc_ppid $$"

			# Skip PID1, our parent, ourself and our children
			[ $pid -ne 1 -a $pid -ne $proc_ppid -a $pid -ne $$ -a $ppid -ne $$ ] || continue

			local cmdline=$(cat /proc/$pid/cmdline)
#			read cmdline < /proc/$pid/cmdline

            echo "cmdline $cmdline"
			# Skip kernel threads
			[ -n "$cmdline" ] || continue

			echo -n "$name "
			kill -$sig $pid 2>/dev/null

			[ $loop -eq 1 ] && run=true
		done

		let loop_limit--
		[ $loop_limit -eq 0 ] && {
			echo
			echo "Failed to kill all processes."
			return 0
			#exit 1
		}
	done
	echo
}

supivot() { # <new_root> <old_root>
    echo "Replacing root with new root in tmpfs..."
    mkdir -p $1$2 $1/proc $1/sys $1/dev $1/tmp &&
        mount -t proc proc $1/proc
    
    pivot_root $1 $1$2 || {
        return 1
    }

    /bin/mount -o noatime,move $2/sys /sys
    /bin/mount -o noatime,move $2/dev /dev

    return 0
}

switch_to_ramfs() {
    echo "Switching to ramfs..."
    mkdir -p $RAM_ROOT
    $(umount $RAM_ROOT 2>/dev/null) || true
    mount -t tmpfs tmpfs $RAM_ROOT
    cp $1 $RAM_ROOT/$UBI_FILENAME
    cp /$LUMI_FILENAME $RAM_ROOT/

    mkdir -p $RAM_ROOT/etc
    mkdir -p $RAM_ROOT/bin
    mkdir -p $RAM_ROOT/sbin
    mkdir -p $RAM_ROOT/lib

    # executables
    cd $RAM_ROOT
    cp /bin/busybox $RAM_ROOT/bin/
    cp /bin/sh $RAM_ROOT/bin/
    cp /bin/sync.coreutils $RAM_ROOT/bin/
    cp /bin/sync $RAM_ROOT/bin/
    cp /usr/sbin/ubi* $RAM_ROOT/bin/
    cp /usr/bin/killall $RAM_ROOT/bin/
    cp /sbin/init $RAM_ROOT/sbin/
    cp /sbin/telinit $RAM_ROOT/sbin
    cp /sbin/getty $RAM_ROOT/sbin/
    cp /bin/start_getty $RAM_ROOT/bin/

    # libraries
    cp /lib/libm.so.6 $RAM_ROOT/lib/
    cp /lib/libc.so.6 $RAM_ROOT/lib/
    cp /lib/ld-linux-armhf.so.3 $RAM_ROOT/lib/
    cp /lib/libtinfo.so.5 $RAM_ROOT/lib/  # sh
    cp /lib/libdl.so.2 $RAM_ROOT/lib/  # sh

    # inittab
    echo > $RAM_ROOT/etc/inittab

    # busybox symlinks
    cd $RAM_ROOT/bin &&
        ln -sf busybox ln &&
        ln -sf busybox cp &&
        ln -sf busybox ls &&
        ln -sf busybox mkdir &&
        ln -sf busybox mount &&
        ln -sf busybox umount &&
        ln -sf busybox reboot &&
        ln -sf busybox cat &&
        ln -sf busybox wc &&
        ln -sf busybox chmod &&
        ln -sf busybox sleep &&
        ln -sf busybox tar

    umount /proc || true
    umount /run  || true
    umount /var/volatile || true
    umount /tmp  || true
    sync

    supivot $RAM_ROOT $OLD_ROOT || {
        echo "Failed to switch over to ramfs. Please reboot."
        exit 1
    }

    /bin/mount -o remount,ro $OLD_ROOT
}

write_image() {
    cd /
    rootfs_length=$( (cat $1 | wc -c) 2>/dev/null)

    cat > /reS <<- EOF
#!/bin/sh
set -x

cd /
sync
telinit u
killall getty

echo 'Unmounting old root...'
#umount -f $OLD_ROOT$RAM_ROOT
umount -f $OLD_ROOT

echo 'Writing rootfs...'
ubirmvol /dev/ubi0 -N rootfs
ubimkvol /dev/ubi0 -N rootfs -m
sync
ubiupdatevol /dev/ubi0_0 -s $rootfs_length $1
sync

echo "Copying Lumi backup..."
mkdir /mnt
mount -t ubifs ubi0:rootfs /mnt
tar -zxvf $LUMI_FILENAME -C /mnt/etc/
sync
umount /mnt

echo 'Flashing complete!'

reboot -f
EOF

    chmod +x /reS
    exec /bin/sh /reS >/dev/ttymxc0 2>&1
}

echo "echo 0 -->> dev/watchdog"
killall key_rgb || true
sleep 1
echo 0 > /dev/watchdog
echo -n V > /dev/watchdog

echo "Writing DTB..."
flash_erase /dev/mtd2 0 0
nandwrite -p /dev/mtd2 -p $DTB_FILE

echo "Writing Kernel..."
flash_erase /dev/mtd1 0 0
nandwrite -p /dev/mtd1 -p $KERNEL_FILE

echo "Backing up Lumi..."
tar -zcvf /$LUMI_FILENAME /lumi/conf

echo "Sending TERM..."
kill_remaining TERM
sleep 1

echo "Sending KILL..."
kill_remaining KILL 1
sleep 1

switch_to_ramfs $UPDATE_FILE
write_image $UBI_FILENAME
