#!/bin/bash
set -e


# REFERENCE:
#   https://davidhamann.de/2019/05/12/tunnel-traffic-over-dns-ssh/


echo_debug "Attempting iodine ..."

if [ -z "$_IODINE_PASSWORD" ] || [ -z "$_IODINE_DOMAIN" ]; then
    echo_warn 'SKIPPING: IODINE will not be configured. _IODINE_PASSWORD and/or _IODINE_DOMAIN are not set.'
else
    chroot_pkginstall install iodine

    # Create iodine startup script (not initramfs)
    cat << EOF > ${CHROOTDIR}/opt/iodine.sh
#!/bin/bash
while true; do
    iodine -f -r -I1 -L0 -P ${_IODINE_PASSWORD} ${_IODINE_DOMAIN}
    sleep 60
done
EOF
    chmod 755 ${CHROOTDIR}/opt/iodine.sh

    cat << EOF > ${CHROOTDIR}/crontab_setup
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
@reboot /opt/iodine.sh
EOF
    chroot_execute crontab /crontab_setup
    rm ${CHROOTDIR}/crontab_setup

    echo_debug "... iodine call completed!"
fi
