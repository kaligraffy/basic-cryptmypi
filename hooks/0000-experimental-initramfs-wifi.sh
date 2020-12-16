#!/bin/bash
set -e


# REFERENCE:
#    http://www.marcfargas.com/posts/enable-wireless-debian-initramfs/
#    https://wiki.archlinux.org/index.php/Dm-crypt/Specialties#Remote_unlock_via_wifi
#    http://retinal.dehy.de/docs/doku.php?id=technotes:raspberryrootnfs


echo_debug "Attempting to set initramfs WIFI up ..."
if [ -z "$_WIFI_SSID" ] || [ -z "$_WIFI_PASS" ]; then
    echo_warn 'SKIPPING: _WIFI_PASSWORD and/or _WIFI_SSID are not set.'
fi

# Checking if WIFI interface was provided
if [ -z "${_INITRAMFS_WIFI_INTERFACE}" ]; then
    _INITRAMFS_WIFI_INTERFACE='wlan0'
    echo_warn "_INITRAMFS_WIFI_INTERFACE is not set on config: Setting default value ${_INITRAMFS_WIFI_INTERFACE}"
fi


# Checking if WIFI ip kernal param was provided
if [ -z "${_INITRAMFS_WIFI_IP}" ]; then
    _INITRAMFS_WIFI_IP=":::::${_INITRAMFS_WIFI_INTERFACE}:dhcp:${_DNS1}:${_DNS2}"
    echo_warn "_INITRAMFS_WIFI_IP is not set on config: Setting default value ${_INITRAMFS_WIFI_IP}"
fi


# Checking if WIFI drivers param was provided
if [ -z "${_INITRAMFS_WIFI_DRIVERS}" ]; then
    _INITRAMFS_WIFI_DRIVERS="brcmfmac brcmutil cfg80211 rfkill"
    echo_warn "_INITRAMFS_WIFI_DRIVERS is not set on config: Setting default value ${_INITRAMFS_WIFI_DRIVERS}"
fi


# Update /boot/cmdline.txt to boot crypt
sed -i "s#rootwait#ip=${_INITRAMFS_WIFI_IP} rootwait#g" ${_CHROOT_ROOT}/boot/cmdline.txt


echo_debug "Generating PSK for '${_WIFI_SSID}' '${_WIFI_PASS}'"
_WIFI_PSK=$(wpa_passphrase "${_WIFI_SSID}" "${_WIFI_PASS}" | grep "psk=" | grep -v "#psk")


echo_debug "Creating hook to include firmware files for brcmfmac"
cat << EOF > ${_CHROOT_ROOT}/etc/initramfs-tools/hooks/zz-brcm
# !/bin/sh
set -e

PREREQ=""
prereqs()
{
    echo "\${PREREQ}"
}

case "\${1}" in
    prereqs)
        prereqs
        exit 0
        ;;
esac

. /usr/share/initramfs-tools/hook-functions

echo "Copying firmware files for brcm to initramfs"
cp -r /lib/firmware/brcm \${DESTDIR}/lib/firmware/

EOF
chmod 755 ${_CHROOT_ROOT}/etc/initramfs-tools/hooks/zz-brcm


echo_debug "Creating wpa_supplicant file"
cat <<EOT > ${_CHROOT_ROOT}/etc/initramfs-tools/wpa_supplicant.conf
ctrl_interface=/tmp/wpa_supplicant

network={
        ssid="${_WIFI_SSID}"
${_WIFI_PSK}
        scan_ssid=1
        key_mgmt=WPA-PSK
}
EOT


echo_debug "Creating initramfs script a_enable_wireless"
cat <<EOT > ${_CHROOT_ROOT}/etc/initramfs-tools/scripts/init-premount/a_enable_wireless
#!/bin/sh

PREREQ=""
prereqs()
{
    echo "\$PREREQ"
}

case \$1 in
prereqs)
    prereqs
    exit 0
    ;;
esac

. /scripts/functions

alias WPACLI="/sbin/wpa_cli -p/tmp/wpa_supplicant -i${_WIFI_INTERFACE} "

log_begin_msg "Sleeping for 5 seconds to allow WLAN interface to become ready"
sleep 5
log_end_msg

log_begin_msg "Starting WLAN connection"
/sbin/wpa_supplicant  -i${_WIFI_INTERFACE} -c/etc/wpa_supplicant.conf -P/run/initram-wpa_supplicant.pid -B -f /tmp/wpa_supplicant.log

# Wait for AUTH_LIMIT seconds, then check the status
AUTH_LIMIT=60

echo -n "Waiting for connection (max \${AUTH_LIMIT} seconds)"
while [ \$AUTH_LIMIT -ge 0 -a \`WPACLI status | grep wpa_state\` != "wpa_state=COMPLETED" ]
do
    sleep 1
    echo -n "."
    AUTH_LIMIT=\`expr \$AUTH_LIMIT - 1\`
done
echo ""

if [ \`WPACLI status | grep wpa_state\` != "wpa_state=COMPLETED" ]; then
  ONLINE=0
  log_failure_msg "WLAN offline after timeout"
  echo
  panic
else
  ONLINE=1
  log_success_msg "WLAN online"
  echo
fi

configure_networking
EOT
chmod +x "${_CHROOT_ROOT}/etc/initramfs-tools/scripts/init-premount/a_enable_wireless"


echo_debug "Creating initramfs hook enable_wireless"
cat <<EOT > ${_CHROOT_ROOT}/etc/initramfs-tools/hooks/enable-wireless
# !/bin/sh
# This goes into /etc/initramfs-tools/hooks/enable-wireless
set -e
PREREQ=""
prereqs()
{
    echo "\${PREREQ}"
}
case "\${1}" in
    prereqs)
        prereqs
        exit 0
        ;;
esac

. /usr/share/initramfs-tools/hook-functions

# Adding wifi drivers
for x in ${_INITRAMFS_WIFI_DRIVERS}; do
    manual_add_modules \${x}
done

copy_exec /sbin/wpa_supplicant
copy_exec /sbin/wpa_cli
copy_file config /etc/initramfs-tools/wpa_supplicant.conf /etc/wpa_supplicant.conf
EOT
chmod +x "${_CHROOT_ROOT}/etc/initramfs-tools/hooks/enable-wireless"


echo_debug "Creating initramfs script kill_wireless"
cat <<EOT > ${_CHROOT_ROOT}/etc/initramfs-tools/scripts/local-bottom/kill_wireless
#!/bin/sh
# this goes into /etc/initramfs-tools/scripts/local-bottom/kill_wireless
PREREQ=""
prereqs()
{
    echo "\$PREREQ"
}

case \$1 in
prereqs)
    prereqs
    exit 0
    ;;
esac

echo "Killing wpa_supplicant so the system takes over later."
kill \`cat /run/initram-wpa_supplicant.pid\`
EOT
chmod +x "${_CHROOT_ROOT}/etc/initramfs-tools/scripts/local-bottom/kill_wireless"


# Adding modules to initramfs modules
for x in ${_INITRAMFS_WIFI_DRIVERS}; do echo ${x} >> ${_CHROOT_ROOT}/etc/initramfs-tools/modules; done


echo_debug "... initramfs wifi completed!"
