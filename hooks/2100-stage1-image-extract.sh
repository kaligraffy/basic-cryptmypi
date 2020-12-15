#!/bin/bash
set -e

IMAGE="${_IMAGEDIR}/${_IMAGENAME}"
EXTRACTEDIMAGE="${_IMAGEDIR}/extracted.img"



if [ -e "$EXTRACTEDIMAGE" ]; then
    echo_info "$EXTRACTEDIMAGE found, skipping extract"
else
    echo_info "Starting extract at $(date)"
    case ${IMAGE} in
        *.xz)
            echo_info "Extracting with xz"
            xz --decompress --stdout ${IMAGE} > $EXTRACTEDIMAGE
            ;;
        *.zip)
            echo_info "Extracting with unzip"
            unzip -p $IMAGE > $EXTRACTEDIMAGE
            ;;
        *)
            echo_error "Unknown extension type on image: $IMAGE"
            exit 1
            ;;
    esac
    echo_info "Finished extract at $(date)"
fi

# Testing Code only (Remove later)
# Skips the loop/mount and copys our preprepared version to the root folder instead.
echo_info "Starting copy of boot to ${_BUILDDIR}/root $(date)"
rsync --hard-links --archive --no-inc-recursive --partial --append-verify --info=progress2 --delete ${_IMAGEDIR}/mount.backup/ ${_BUILDDIR}/root
#--delete SHOULD RESTORE $BUILDDIR TO MOUNTBACKUP LEVEL OF EXTRACTION
#HOWEVER LOTS OF THE STUFF THAT GETS MOUNTED NEEDS TO BE CHECKED TO BE
#REMOVED OTHERWISE IT'LL FUCK IT ALL UP! PUT IN A CHECK TO
#CHECK TO SEE IF ANYTHING IS MOUNTED IN THE CHROOT FOR IT
#AND UNMOUNT IT. CALL THE CHROOTUNMOUNT FUNCTION IF IT'S USABLE
echo_info "Finished copy of boot to ${_BUILDDIR}/root $(date)"
return 0;
# End of test code.

echo_debug "Mounting loopback ..."
loopdev=$(losetup -P -f --show "$EXTRACTEDIMAGE")

mkdir $_BUILDDIR/mount
echo_debug "Unmounted $_BUILDDIR/boot $(date)"
mount ${loopdev}p2 ${_BUILDDIR}/mount/
mount ${loopdev}p1 ${_BUILDDIR}/mount/boot

echo_info "Starting copy of boot to ${_BUILDDIR}/boot $(date)"
rsync -Ha --no-inc-recursive --partial --append-verify --info=progress2 --delete ${_BUILDDIR}/mount/ ${_BUILDDIR}/root
echo_info "Finished copy of boot to ${_BUILDDIR}/boot $(date)"

echo_debug "Unmounted ${_BUILDDIR}/boot $(date)"
umount ${_BUILDDIR}/mount/boot
umount ${_BUILDDIR}/mount
rmdir ${_BUILDDIR}/mount
echo_debug "Cleaning loopback ..."
losetup -d ${loopdev}
echo "Removing extracted image"
#rm $EXTRACTEDIMAGE
