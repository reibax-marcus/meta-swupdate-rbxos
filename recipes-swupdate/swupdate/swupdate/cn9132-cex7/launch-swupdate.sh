#!/bin/bash

SCRIPTS_TMP_DIR=/tmp/scripts

get_boot_device()
{
    for i in `cat /proc/cmdline`; do
        case "$i" in
            root=*)
                ROOT="${i#root=}"
                ;;
        esac
    done
    BOOTDEV="unknown"
    if grep -q "mmcblk0" /proc/cmdline ; then
        BOOTDEV="mmcblk0"
	COPYMOD="emmc"
    fi
    if grep -q "mmcblk1" /proc/cmdline ; then
        BOOTDEV="mmcblk1"
	COPYMOD="sdcard"
    fi
}

[ ! -d ${SCRIPTS_TMP_DIR} ] && mkdir -p ${SCRIPTS_TMP_DIR}

get_boot_device

if [ $ROOT == "/dev/${BOOTDEV}p5" ];then
    selection="-e stable,copy2${COPYMOD}"
else
    selection="-e stable,copy1${COPYMOD}"
fi

exec /usr/bin/swupdate $selection -v -w "-r /www/swupdate" -f /etc/swupdate.cfg -k /www/swupdate/keys/public.pem -K /usr/share/upgrade-keys/aes256.key -p reboot
