chroot_mount(){
    export CHROOTDIR=$1

    echo_debug "Preparing RPi chroot mount structure at '${CHROOTDIR}'."
    [ -z "${CHROOTDIR}" ] && {
        echo_error "Chroot dir was not defined! Aborting..."
        exit 1
    }

    # mount binds
    echo_debug "Mounting '${CHROOTDIR}/dev/' ..."
    mount --bind /dev ${CHROOTDIR}/dev/ || echo_error "ERROR while mounting '${CHROOTDIR}/dev/'"
    echo_debug "Mounting '${CHROOTDIR}/dev/pts' ..."
    mount --bind /dev/pts ${CHROOTDIR}/dev/pts || echo_error "ERROR while mounting '${CHROOTDIR}/dev/pts'"
    echo_debug "Mounting '${CHROOTDIR}/sys/' ..."
    mount --bind /sys ${CHROOTDIR}/sys/ || echo_error "ERROR while mounting '${CHROOTDIR}/sys/'"
    echo_debug "Mounting '${CHROOTDIR}/proc/' ..."
    mount -t proc /proc ${CHROOTDIR}/proc/ || echo_error "ERROR while mounting '${CHROOTDIR}/proc/'"

    # ld.so.preload fix
    test -e ${CHROOTDIR}/etc/ld.so.preload && {
        echo_debug "Fixing ld.so.preload"
        sed -i 's/^/#CHROOT /g' ${CHROOTDIR}/etc/ld.so.preload
    } || true
}


chroot_umount(){
    [ -z "${CHROOTDIR}" ] && {
        exit 1
    }
    echo_debug "Tearing down RPi chroot mount structure at '${CHROOTDIR}'."

    # revert ld.so.preload fix
    test -e ${CHROOTDIR}/etc/ld.so.preload && {
        echo_debug "Reverting ld.so.preload fix"
        sed -i 's/^#CHROOT //g' ${CHROOTDIR}/etc/ld.so.preload
    } || true

    # unmount everything
    echo_debug "Unmounting binds"
    umount ${CHROOTDIR}/{dev/pts,dev,sys,proc}

    export CHROOTDIR=''
}


chroot_update(){
    [ -z "${CHROOTDIR}" ] && {
        echo_error "Chroot dir was not defined! Aborting..."
        exit 1
    }
    
    #Force https on initial use of apt
    sed -i 's|http:|https:|g' ${CHROOTDIR}/etc/apt/sources.list
    
    if [ -f "${CHROOTDIR}/etc/resolv.conf" ]; then
        echo_debug "${CHROOTDIR}/etc/resolv.conf exists."
    else
        echo_warn "${CHROOTDIR}/etc/resolv.conf does not exists."
        echo_warn "Setting nameserver to $_DNS1 and $_DNS2 in ${CHROOTDIR}/etc/resolv.conf"
        echo -e "nameserver $_DNS1\nnameserver $_DNS2" > "${CHROOTDIR}/etc/resolv.conf"
    fi

    echo_debug "Updating apt-get"
    chroot ${CHROOTDIR} apt-get update
}


chroot_pkginstall(){
    [ -z "${CHROOTDIR}" ] && {
        echo_error "Chroot dir was not defined! Aborting..."
        exit 1
    }

    if [ ! -z "$1" ]; then
        for param in "$@"; do
            for pkg in $param; do
                echo_debug "- Installing ${pkg}"
                chroot ${CHROOTDIR} apt-get -qq install "${pkg}" || {
                    echo_warn "apt-get failed: Trying to recover..."
                    chroot ${CHROOTDIR} /bin/bash -x <<EOF
                        sleep 5
                        apt-get update
                        apt-get -qq install "${pkg}" || exit 1
EOF
                    status=$?
                    [ $status -eq 0 ] || {
                        echo_error "ERROR: Could not install ${pkg} correctly... Exiting.";
                        exit 1
                    }
                }
            done
        done
    fi
}


chroot_pkgpurge(){
    [ -z "${CHROOTDIR}" ] && {
        echo_error "Chroot dir was not defined! Aborting..."
        exit 1
    }

    if [ ! -z "$1" ]; then
        for param in "$@"; do
            for pkg in $param; do
                echo_debug "- Purging ${pkg}"
                chroot ${CHROOTDIR} apt-get -y purge "${pkg}"
            done
        done
        chroot ${CHROOTDIR} apt-get -y autoremove
    fi
}


chroot_execute(){
    [ -z "${CHROOTDIR}" ] && {
        echo_error "Chroot dir was not defined! Aborting..."
        exit 1
    }

    chroot ${CHROOTDIR} "$@"
}


chroot_mkinitramfs(){
    echo_debug "Attempting to build new initramfs ... (CHROOT is ${CHROOTDIR})"

    # crypttab needs to point to the current physical device during mkinitramfs or cryptsetup won't deploy
    echo_debug "  Creating symbolic links from current physical device to crypttab device (if not using sd card mmcblk0p)"
    test -e "/dev/mmcblk0p1" || (test -e "/${_BLKDEV}1" && ln -s "/${_BLKDEV}1" "/dev/mmcblk0p1")
    test -e "/dev/mmcblk0p2" || (test -e "/${_BLKDEV}2" && ln -s "/${_BLKDEV}2" "/dev/mmcblk0p2")

    # determining the kernel
    _KERNEL_VERSION=$(ls ${CHROOTDIR}/lib/modules/ | grep "${_KERNEL_VERSION_FILTER}" | tail -n 1)
    echo_debug "  Using kernel '${_KERNEL_VERSION}'"
    chroot_execute update-initramfs -u -k all
    # Finally, Create the initramfs
    echo_debug "  Building new initramfs ..."
    chroot_execute mkinitramfs -o /boot/initramfs.gz -v ${_KERNEL_VERSION}

    # cleanup
    echo_debug "  Cleaning up symbolic links"
    test -L "/dev/mmcblk0p1" && unlink "/dev/mmcblk0p1"
    test -L "/dev/mmcblk0p2" && unlink "/dev/mmcblk0p2"
}
