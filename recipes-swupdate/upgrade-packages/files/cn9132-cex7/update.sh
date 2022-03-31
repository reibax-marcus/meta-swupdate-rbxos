#!/bin/bash

get_boot_device()
{
    # shellcheck disable=SC2013
    for i in $(cat /proc/cmdline); do
        case "$i" in
            root=*)
                ROOT="${i#root=}"
                ;;
        esac
    done
    if [ "${ROOT}" = "unknown" ] || [ -z "${ROOT}" ] || [ ! -e "${ROOT}" ] ; then
        echo "ERROR: root partition not found in cmdline. ${ROOT}" >&2
        exit 1
    fi
    BOOTDEV="$(basename "${ROOT}" | cut -d'p' -f1)"
    if [ -z "${BOOTDEV}" ] || [ ! -e "/dev/${BOOTDEV}" ] ; then
        echo "ERROR: root partition not found in cmdline. ${BOOTDEV}" >&2
        exit 1
    fi
}

get_boot_device

MMC_ENV_DEV=${BOOTDEV}boot1
MNT=/mnt/bootfiles
ROOTPART1=/dev/${BOOTDEV}p5
UPGRADE_OVERLAY_CLEANELEMENTS="/bin /usr/bin /lib /usr/lib /var/lib /opt /etc/license.manifest"

get_partition_for_bootfiles()
{
    if [ "${ROOT}" = "${ROOTPART1}" ]; then
        echo "p2"
    else
        echo "p1"
    fi
}

mount_bootfiles_partition()
{
    local partition=$1

    # Before we try to mount the boot partition, try to run fsck
    systemctl start "systemd-fsck@dev-${BOOTDEV}${partition}.service"

    [ ! -d ${MNT} ] && mkdir -p ${MNT}
    mount "/dev/${BOOTDEV}${partition}" "${MNT}"
}

umount_bootfiles_partition()
{
    umount ${MNT}
    [ -d ${MNT} ] && rmdir ${MNT}
}

mark_postinst_on_reboot() {
    mkdir -p "${1}etc/swu-postinst"
    touch "${1}etc/swu-postinst/populate_pending"
    sync
}

# XXX - Warning! If we ever do rollback on data migration after boot we need to
# take care of the fsbl
check_install_fsbl()
{
    FSBL_DEV="/dev/${BOOTDEV}"
    FSBL_FILEDIR="/tmp/fsbl"
    FSBL_FILENAME="${FSBL_FILEDIR}/flash-image.bin"
    FSBL_OLD="${FSBL_FILEDIR}/flash-image.old"
    MAX_RETRIES=3

    # Sanity checks
    mkdir -p "${FSBL_FILEDIR}"
    if [ ! -f "${FSBL_FILENAME}" ] ; then
        echo "${FSBL_FILENAME} firmware file not found" >&2
        return 1
    fi
    if [ ! -b "${FSBL_DEV}" ] ; then
        echo "${FSBL_DEV} device not found" >&2
        return 1
    fi
    # shellcheck disable=SC2230
    if ! which dd >/dev/null ; then
        echo "dd tool needed to upgrade the fsbl" >&2
        return 1
    fi

    # Extract and compare versions
    if ! dd if="${FSBL_DEV}" bs=512 seek=4096 count=8192 of="${FSBL_OLD}" 2>&1 ; then
        echo "ERROR: Unexpected error while trying to extract current fsbl" >&2
        return 1
    fi
    INSTALLED_FSBL_VER="$(strings "${FSBL_OLD}" | grep bsupver | cut -d[ -f2 | cut -d] -f1)"
    NEW_FSBL_VER="$(strings "${FSBL_FILENAME}" | grep bsupver | cut -d[ -f2 | cut -d] -f1)"
    echo "Installed fsbl version: $INSTALLED_FSBL_VER"
    echo "New fsbl version: $NEW_FSBL_VER"
    if [ -z "${NEW_FSBL_VER}" ] ; then
        echo "ERROR: new fsbl version is empty" >&2
        return 1
    fi

    if [ "${INSTALLED_FSBL_VER}" != "${NEW_FSBL_VER}" ] ; then
        UPGRADE_COMPLETE="n"
        RETRIES=0
        while [ "${UPGRADE_COMPLETE}" != "y" ] && [ ${RETRIES} -lt ${MAX_RETRIES} ] ; do
            echo "Upgrading fsbl..."
            if dd if="${FSBL_FILENAME}" of="${FSBL_DEV}" bs=512 seek=4096 2>&1 && sync ; then
                UPGRADE_COMPLETE="y"
            fi
            RETRIES="$((RETRIES+1))"
        done
        if [ "${UPGRADE_COMPLETE}" == "y" ] ; then
            echo "fsbl upgrade done"
            return 0
        else
            echo "ERROR while trying to upgrade fsbl"
            return 1
        fi
    else
        echo "FSBL upgrade not needed"
        return 0
    fi
}

# Remount rootfs as read-only and copy overlay partition
prepare_data_migration()
{
    # Identify active and backup overlay partitions
    get_boot_device
    if [ "${ROOT}" = "${ROOTPART1}" ] ; then
        OVERLAY_DEV_STORAGE="/dev/${BOOTDEV}p7"
        OVERLAY_DEV_BACKUP="/dev/${BOOTDEV}p8"
    else
        OVERLAY_DEV_STORAGE="/dev/${BOOTDEV}p8"
        OVERLAY_DEV_BACKUP="/dev/${BOOTDEV}p7"
    fi
    OVERLAY_ACTIVE="/tmp/overlay_active"
    OVERLAY_BACKUP="/tmp/overlay_backup"
    echo "Active Overlay Device: ${OVERLAY_DEV_STORAGE}"
    echo "Backup Overlay Device: ${OVERLAY_DEV_BACKUP}"

    # If we are on a system that was not able to handle
    # both overlay partitions we may need to wait for the
    # next upgrade to start using the system
    # shellcheck disable=SC2012
    EXT4MOUNTS="$(ls -d /sys/fs/ext4/${BOOTDEV}p* | wc -w)"
    # shellcheck disable=SC2086
    if [ ${EXT4MOUNTS} -eq 1 ] ; then
      OVERLAY_DEV_CHECK="$(basename /sys/fs/ext4/${BOOTDEV}p*)"
      export OVERLAY_DEV_CHECK
      if [ "${ROOT}" != "${ROOTPART1}" ] &&
        [ "${OVERLAY_DEV_CHECK}" = "${BOOTDEV}p7" ] ; then
        echo "WARNING: Second partition set on first overlay partition. Old system overlay system?"
        # Mark postinst to perform actions on next boot
        mark_postinst_on_reboot "/"
        return 0
      fi
    fi

    # Remount rootfs as read-only
    echo "Syncing ${OVERLAY_DEV_CHECK} overlay before remounting as read only"
    sync
    echo "Remounting ${OVERLAY_DEV_CHECK} overlay read only"
    mount -o remount,ro /

    # Format unused overlay partition
    echo "Formatting unused overlay partition ${OVERLAY_DEV_BACKUP}..."
    if ! mkfs.ext4 -F ${OVERLAY_DEV_BACKUP} -O 64bit 2>&1 ; then
        echo "ERROR: Unexpected error while formatting backup overlay partition"
        echo "Remounting ${OVERLAY_DEV_CHECK} overlay read write"
        mount -o remount,rw /
        return 1
    fi
    echo "Unused overlay partition format DONE"

    # Mount both overlay partitions
    mkdir -p "${OVERLAY_ACTIVE}" "${OVERLAY_BACKUP}"
    if ! mount -o loop,ro,norecovery "${OVERLAY_DEV_STORAGE}" "${OVERLAY_ACTIVE}" ; then
        echo "ERROR: Couldn't mount current active overlay partition"
        echo "Remounting ${OVERLAY_DEV_CHECK} overlay read write"
        mount -o remount,rw /
        return 1
    fi
    if ! mount "${OVERLAY_DEV_BACKUP}" "${OVERLAY_BACKUP}" ; then
        echo "ERROR: Couldn't mount backup overlay partition"
        echo "Remounting ${OVERLAY_DEV_CHECK} overlay read write"
        mount -o remount,rw /
        return 1
    fi

    # Copy the current overlay partition over to the unused partition
    echo "Copying current overlay partition over to backup overlay partition..."
    if ! cp -a "${OVERLAY_ACTIVE}/." "${OVERLAY_BACKUP}/" ; then
        echo "ERROR: Unexpected error while copying files from active overlay to backup overlay"
        echo "Remounting ${OVERLAY_DEV_CHECK} overlay read write"
        mount -o remount,rw /
        return 1
    fi
    echo "Overlay partition copy DONE"

    # Clean parts of the overlay that we don't want to carry between upgrades
    echo "Cleaning backup overlay partition directories that we want to keep clean..."
    for cleanelmnt in ${UPGRADE_OVERLAY_CLEANELEMENTS} ; do
        if ! rm -fr "${OVERLAY_BACKUP}/rw/${cleanelmnt}" ; then
            echo "ERROR: Unexpected error while cleaning overlay partition"
            echo "Remounting ${OVERLAY_DEV_CHECK} overlay read write"
            mount -o remount,rw /
            return 1
        fi
    done
    echo "Overlay partition directories cleaned"

    # Umount active overlay partition
    echo "Umounting active overlay partition..."
    umount "${OVERLAY_ACTIVE}"
    echo "Overlay partition umount DONE"

    # Mark postinst to perform actions on next boot
    mark_postinst_on_reboot "${OVERLAY_BACKUP}/rw/"

    # Umount backup overlay partition
    echo "Umounting backup overlay partition..."
    umount "${OVERLAY_BACKUP}"
    echo "Overlay partition umount DONE"

    echo "Remounting ${OVERLAY_DEV_CHECK} overlay read write"
    mount -o remount,rw /
    return 0
}

if [ $# -lt 1 ]; then
    exit 0;
fi

if [ "$1" == "preinst" ] ; then
    echo "$0: PREINST CALLED"
    # Abort upgrade if this system already has an older partition table scheme
    get_boot_device
    mount_bootfiles_partition "$(get_partition_for_bootfiles)"
    if [ -e "/sys/block/${MMC_ENV_DEV}/force_ro" ] ; then
        echo 0 > /sys/block/${MMC_ENV_DEV}/force_ro
    fi
    mkdir -p /tmp/fsbl
    exit 0
fi

if [ "$1" == "postinst" ] ; then
    echo "$0: POSTINST CALLED"
    # VERIFY VERSION FILES CHECKSUMS??
    umount_bootfiles_partition

    # Any package needing a migration process shall put a script
    # that will perform any necessary migration actions on the first
    # post upgrade reboot on the following path: ${sysconfdir}/swu-postinst/collection/
    # XXX - Warning! If we ever do rollback on data migration after boot we need to
    # take care of the fsbl
    prepare_data_migration || exit $?

    check_install_fsbl || exit $?

    echo "POSTINST OK"
    sleep 1 # Needed to avoid losing debug messages
    exit 0
fi

