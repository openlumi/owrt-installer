#!/bin/sh

if [ "$#" -ne "2" ]; then 
    echo -e "Usage:\n\t$0 <dtb> <kernel>"
    exit 1
fi

if [ ! -f "$1" ]; then
    echo "$1 doesn't exist!"
    exit 1
fi

if [ ! -s $1 ]; then
    echo "$1 is empty! Cannot proceed"
    exit 1
fi

if [ ! -f "$2" ]; then
    echo "$2 doesn't exist!"
    exit 1
fi

if [ ! -s $2 ]; then
    echo "$2 is empty! Cannot proceed"
    exit 1
fi

DTB=$1
KERNEL=$2

echo "Writing DTB..."
flash_erase /dev/mtd2 0 0
nandwrite -p /dev/mtd2 -p $DTB

echo "Writing kernel..."
flash_erase /dev/mtd1 0 0
nandwrite -p /dev/mtd1 -p $KERNEL
