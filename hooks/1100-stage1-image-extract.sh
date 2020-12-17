#!/bin/bash
set -e

unmount_gracefully() {
    umount  "${_BUILD_DIR}/mount" || true
    umount  "${_BUILD_DIR}/boot" || true
    losetup -d "${loopdev}p1" || true
    losetup -d "${loopdev}p2" || true
    losetup -D || true
    rm -rf ${_BUILD_DIR}/mount || true
    rm -rf ${_BUILD_DIR}/boot || true
}

rollback()
{
    echo_error "Rolling back!"
    rm -rf "${_CHROOT_ROOT}" || true;
    unmount_gracefully
}

extract_image() {
    local image_name=$(basename ${_IMAGE_URL})
    local image="${_FILE_DIR}/${image_name}"
    local extracted_image="${_FILE_DIR}/extracted.img"

    if [ -e "$extracted_image" ]; then
        echo_info "$extracted_image found, skipping extract"
    else
        echo_info "Starting extract at $(date)"
        case ${image} in
            *.xz)
                echo_info "Extracting with xz"
                trap "rm -f $extracted_image; exit 1" ERR SIGINT
                pv ${image} | xz --decompress --stdout > "$extracted_image"
                trap - ERR SIGINT
                ;;
            *.zip)
                echo_info "Extracting with unzip"
                unzip -p $image > "$extracted_image"
                ;;
            *)
                echo_error "Unknown extension type on image: $IMAGE"
                exit 1
                ;;
        esac
        echo_info "Finished extract at $(date)"
    fi

    trap "rollback" ERR SIGINT
    echo_debug "Mounting loopback";
    loopdev=$(losetup -P -f --show "$extracted_image");
    partprobe ${loopdev};
    mkdir "${_BUILD_DIR}/mount"
    mkdir "${_BUILD_DIR}/boot"
    mkdir "${_CHROOT_ROOT}"
    mount ${loopdev}p2 ${_BUILD_DIR}/mount
    mount ${loopdev}p1 ${_BUILD_DIR}/boot
    echo_info "Starting copy of boot to ${_CHROOT_ROOT}/boot at $(date)"
    rsync \
        --hard-links \
        --archive \
        --verbose \
        --partial \
        --progress \
        --quiet \
        --info=progress2 "${_BUILD_DIR}/boot" "${_CHROOT_ROOT}/"

    echo_info "Starting copy of mount to ${_CHROOT_ROOT} at $(date)"
    rsync \
        --hard-links \
        --archive \
        --verbose \
        --partial \
        --progress \
        --quiet \
        --info=progress2 "${_BUILD_DIR}/mount/"* "${_CHROOT_ROOT}"
    trap - ERR SIGINT
    unmount_gracefully
}
extract_image
