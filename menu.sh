#!/bin/sh

if [ -f /etc/os-release ]; then
  . /etc/os-release
else
  echo "Unsupported OS"
  exit -1
fi

is_openwrt() {
  [ "x$OPENWRT_RELEASE" != "x" ];
}

get_latest_ver() {
  # TODO: Fetch dynamically
  case $1 in
    19)
      INSTALL_VERSION="19.07.8"
      ;;
    21)
      INSTALL_VERSION="21.02.1"
      ;;
    *)
      echo "Wrong version"
      exit -1
      ;;
  esac
}

get_my_ip() {
  if [ "x$MY_IP" = "x" ]; then
    MY_IP=$(ifconfig wlan0 | grep "inet addr" | awk '{print $2}' | cut -f2 -d:)
  fi
}

detect_rtl_type() {
  if [ "x$RTL_TYPE" = "x" ]; then
    if [ -f /sys/class/net/wlan0/device/device ]; then
      RTL_TYPE=$(cat /sys/class/net/wlan0/device/device)
    else
      RTL_TYPE="(unknown)"
    fi
  fi
}

is_aquara() {
  detect_rtl_type
  [ $RTL_TYPE = "0x8179" ];
}

is_xiaomi() {
  detect_rtl_type
  [ $RTL_TYPE = "0xb723" ];
}

w_get() {
  if is_openwrt; then
    wget https://$1$2 -O $3
  else
    echo -e "GET $2 HTTP/1.0\nHost: $1\n" | openssl s_client -quiet -connect $1:443 -servername $1 2>/dev/null | sed '1,/^\r$/d' > $3
  fi
}

bold() { 
  echo -ne "\033[1m$1\033[0m" 
}
bye() { 
  echo; echo "Bye"; exit 0; 
}

spacer() {
  echo " -----------------------------------------------------"
  echo
}

await() {
  read -rsn1 -p "Press any key to continue"
  echo
}

header() {
  clear

  local BRAND="(unknown)"
  if is_aquara; then
    BRAND="Aquara"
  elif is_xiaomi; then
    BRAND="Xiaomi"
  fi

  if is_openwrt; then
    echo -e "OS: $(bold "$OPENWRT_RELEASE") K: $(bold `uname -r`) B: $(bold $BRAND)"
  else
    echo -e "OS: $(bold "Yocto Lumi $LUMI_VERSION") K: $(bold `uname -r`) B: $(bold $BRAND) SN: $(bold $SN)"
  fi

  spacer
}

openwrt_main_menu() {
  #stock_install_menu
}

stock_main_menu() {
  while true
  do
    header
    echo "Avialable actions:"
    echo
    echo "1) Backup OS"
    echo "2) Install OpenWrt"
    echo "0) Exit"
    echo
    echo "Choose an option:  "
    read -r ans
    case $ans in
      1)
        stock_backup_menu
        ;;
      2)
        stock_install_menu
        ;;
      0)
        bye
        ;;
    esac
  done
}

stock_install_menu() {
  while true
  do
    header
    echo "Avialable actions:"
    echo
    echo "1) Install OpenWrt 21.02"
    echo "2) Install OpenWrt 19.07"
    echo "0) Return"
    echo
    echo "Choose an option:  "
    read -r ans
    case $ans in
      1)
        stock_install 21
        ;;
      2)
        stock_install 19
        ;;
      0)
        break
        ;;
    esac
  done
}

stock_install() {
  local ver=$1
  local WORKDIR=$(mktemp -d)
  get_latest_ver "$ver"

  header
  echo "Cleaning backups..."
  rm -f /tmp/lumi_stock*.tar.gz

  echo
  echo "Updating time..."
  ntpdate pool.ntp.org

  echo
  echo "Downloading curl..."
  w_get raw.githubusercontent.com /openlumi/owrt-installer/main/curl $WORKDIR/curl
  chmod +x $WORKDIR/curl
  CURL="$WORKDIR/curl --insecure -L"

  BASE_URL=https://openlumi.github.io/releases/${INSTALL_VERSION}/targets/imx6/generic
  if [ $ver = "21" ]; then
    if is_xiaomi; then
      SUP_FILE=openlumi-${INSTALL_VERSION}-imx6-xiaomi_dgnwg05lm-squashfs-sysupgrade.bin
      DTB_FILE=openlumi-${INSTALL_VERSION}-imx6-imx6ull-xiaomi-dgnwg05lm.dtb
    else
      SUP_FILE=openlumi-${INSTALL_VERSION}-imx6-aqara_zhwg11lm-squashfs-sysupgrade.bin
      DTB_FILE=openlumi-${INSTALL_VERSION}-imx6-imx6ull-aqara-zhwg11lm.dtb
    fi
  elif [ $ver = "19" ]; then
    SUP_FILE=openlumi-${INSTALL_VERSION}-imx6-lumi-squashfs-sysupgrade.bin
    DTB_FILE=openlumi-${INSTALL_VERSION}-imx6-imx6ull-xiaomi-lumi.dtb
  else
    echo "$(bold Wrong version!)"
    await
    return
  fi

  echo "Downloading packages..."
  $CURL -s -o $WORKDIR/sha256sum $BASE_URL/sha256sums
  $CURL -s -o $WORKDIR/$DTB_FILE $BASE_URL/$DTB_FILE
  $CURL -o $WORKDIR/$SUP_FILE $BASE_URL/$SUP_FILE

  if [ $ver = "21" ]; then
    UBOOT_FILE=u-boot.imx
    $CURL -o $WORKDIR/$UBOOT_FILE $BASE_URL/u-boot-xiaomi_dgnwg05lm/$UBOOT_FILE
  fi

  echo
  echo "Checking packages..."
  pushd $WORKDIR >/dev/null
    if [ $ver = "21" ]; then
      if [ ! -s $WORKDIR/$UBOOT_FILE ]; then
        echo U-Boot download failed, please check available space and try again.
        await
        return
      fi
    fi

    cat $WORKDIR/sha256sum | grep $DTB_FILE | sha256sum -c
    if [ $? -ne 0 ]; then
      echo "DTB file $(bold checksum mismatch), please check available space and try again."
      await
      return
    fi

    cat $WORKDIR/sha256sum | grep $SUP_FILE | sha256sum -c
    if [ $? -ne 0 ]; then
      echo "SysUpgrade file $(bold checksum mismatch), please check available space and try again."
      await
      return
    fi 
  popd >/dev/null

  echo
  echo "Unpacking packages..."
  if ! tar -xvf $WORKDIR/$SUP_FILE -C $WORKDIR; then
    echo Unpacking failed, please check available space and try again.
    exit -1
  fi
  rm $WORKDIR/$SUP_FILE
  mv $WORKDIR/sysupgrade-*/kernel $WORKDIR/
  mv $WORKDIR/sysupgrade-*/root $WORKDIR/
  rm -rf $WORKDIR/sysupgrade-*

  echo
  echo "Generating sysupgrade backup..."
  stock_create_sup_backup $WORKDIR/sysupgrade.tgz

  echo "Generating install script..."
  stock_install_script $WORKDIR/update.sh
  chmod +x $WORKDIR/update.sh

  
  echo
  echo "================================================================="
  echo "Last chance!!! Stock OS would be replaced with OpenWRT."
  echo "================================================================="
  echo
  read -p "Continue (y/n)? " choice
  case "$choice" in 
    y|Y ) echo "OK, starting...";;
    * ) echo "no"; return;;
  esac

  if [ $ver = "21" ]; then
    echo
    echo "Writing u-boot..."
    kobs-ng init -x -v --chip_0_device_path=/dev/mtd0 $WORKDIR/$UBOOT_FILE 
  fi

  echo
  echo "Writing DTB..."
  flash_erase /dev/mtd2 0 0
  nandwrite -p /dev/mtd2 -p $WORKDIR/$DTB_FILE

  echo
  echo "Writing Kernel..."
  flash_erase /dev/mtd1 0 0
  nandwrite -p /dev/mtd1 -p $WORKDIR/kernel

  echo
  echo "Writing rootfs..."
  setsid $WORKDIR/update.sh $WORKDIR/root $WORKDIR/sysupgrade.tgz >/dev/ttymxc0 2>&1 < /dev/null &
  
  await
  exit 0
}

stock_install_script() {
  local file=$1

  cat > $file <<- "EOT"
#!/bin/sh
RAM_ROOT=/tmp/root
OLD_ROOT=/old-root

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
#     read cmdline < /proc/$pid/cmdline

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
  /bin/mount -o noatime,move $2/tmp /tmp

  return 0
}

switch_to_ramfs() {
  echo "Switching to ramfs..."
  mkdir -p $RAM_ROOT
  $(umount $RAM_ROOT 2>/dev/null) || true
  mount -t tmpfs tmpfs $RAM_ROOT

  mkdir -p $RAM_ROOT/etc
  mkdir -p $RAM_ROOT/bin
  mkdir -p $RAM_ROOT/mnt
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
umount -f $OLD_ROOT

echo 'Writing rootfs...'
ubirmvol /dev/ubi0 -N rootfs
ubimkvol /dev/ubi0 -Nrootfs -s $rootfs_length
ubimkvol /dev/ubi0 -Nrootfs_data -m
sync
ubiupdatevol /dev/ubi0_0 $1
sync

echo "Copying Lumi backup..."
mount -t ubifs ubi0:rootfs_data /mnt
cp $2 /mnt/
sync
umount /mnt

echo 'Flashing complete!'
reboot -f
EOF

  chmod +x /reS
  exec /bin/sh /reS >/dev/ttymxc0 2>&1
}

if [ "$#" -ne "2" ]; then 
  echo -e "Usage:\n\t$0 <rootfs> <sysupgrade.tgz>"
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

echo "echo 0 -->> dev/watchdog"
killall key_rgb || true
sleep 1
echo 0 > /dev/watchdog
echo -n V > /dev/watchdog

echo "Sending TERM..."
kill_remaining TERM
sleep 1

echo "Sending KILL..."
kill_remaining KILL 1
sleep 1

switch_to_ramfs
write_image $1 $2
EOT
}

stock_create_sup_backup() {
  local file=$1
  local WORKDIR=$(mktemp -d)

  mkdir -p $WORKDIR/etc/lumi/
  mkdir -p $WORKDIR/etc/config/
  mkdir -p $WORKDIR/lib/upgrade/keep.d/
  echo /etc/lumi/ > $WORKDIR/lib/upgrade/keep.d/lumi
  stock_convert_wifi $WORKDIR/etc/config/wireless
  cp -aPrv /lumi/conf $WORKDIR/etc/lumi/
  tar -C $WORKDIR -zcvf $file .
  rm -rf $WORKDIR
}

stock_convert_wifi() {
  local file=$1

  . /lumi/conf/wifi.conf

  if [ $key_mgmt = "WPA" ]; then
    ENC=psk
  elif [ $key_mgmt = "WPA2" ]; then
    ENC=psk2
  else
    ENC=psk2
  fi

  cat > $file <<- EOF

config wifi-device 'radio0'
        option type 'mac80211'
        option channel '11'
        option hwmode '11g'
        option path 'soc0/soc/2100000.aips-bus/2190000.usdhc/mmc_host/mmc0/mmc0:0001/mmc0:0001:1'
        option htmode 'HT20'

config wifi-iface 'default_radio0'
        option device 'radio0'
        option network 'wwan'
        option mode 'sta'
        option key '$psk'
        option ssid '$ssid'
        option encryption '$ENC'

config wifi-device 'radio1'
        option type 'mac80211'
        option channel '11'
        option hwmode '11g'
        option path 'soc0/soc/2100000.aips-bus/2190000.usdhc/mmc_host/mmc0/mmc0:0001/mmc0:0001:1+1'
        option htmode 'HT20'
        option disabled '1'

config wifi-iface 'default_radio1'
        option device 'radio1'
        option network 'lan'
        option mode 'ap'
        option ssid 'OpenWrt'
        option encryption 'none'
        option disabled '1'

EOF
}

stock_backup_menu() {
  while true  
  do
    header
    echo "Available actions:"
    echo 
    echo "1) Full backup"
    echo "2) Lite backup (lumi config only)"
    echo "0) Return"
    echo
    echo "Choose an option:  "
    read -r ans
    case $ans in
      1)
        stock_full_backup
        ;;
      2)
        stock_lite_backup
        ;;
      0)
        break
        ;;
    esac
  done
}

stock_full_backup() {
  header
  get_my_ip
  echo "Doing FULL backup..."
  tar -cvpzf /tmp/lumi_stock.tar.gz --exclude='./tmp/*' --exclude='./proc/*' --exclude='./sys/*' -C / .
  spacer
  echo "Make sure to copy $(bold /tmp/lumi_stock.tar.gz) to your PC!!!"
  echo "Example: $(bold scp) root@$MY_IP:$(bold /tmp/lumi_stock.tar.gz) ."
  echo
  await
}

stock_lite_backup() {
  header
  get_my_ip
  echo "Doing LITE backup..."
  tar -cvpzf /tmp/lumi_stock_conf.tar.gz -C / /lumi/conf /etc/os-release
  spacer
  echo "Make sure to copy $(bold /tmp/lumi_stock_conf.tar.gz) to your PC!!!"
  echo "Example: $(bold scp) root@$MY_IP:$(bold /tmp/lumi_stock_conf.tar.gz) ."
  echo
  await
}

menu() {
  if is_openwrt; then
    openwrt_main_menu
  else
    stock_main_menu
  fi
}

menu
