#!/bin/bash
set -e

echo_debug "Partitioning SD Card"
parted ${_BLKDEV} --script -- mklabel msdos
parted ${_BLKDEV} --script -- mkpart primary fat32 0 256
parted ${_BLKDEV} --script -- mkpart primary 256 -1
sync
