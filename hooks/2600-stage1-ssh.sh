#!/bin/bash
set -e
set -u

test -f "${_SSH_LOCAL_KEYFILE}" || {
        echo_error "ERROR: Obligatory SSH keyfile '${_SSH_LOCAL_KEYFILE}' could not be found. "
        exit 1
}

# Append our key to the default user's authorized_keys file
echo_debug "Creating authorized_keys file"
mkdir -p "${_CHROOT_ROOT}/.ssh/"
cat "${_SSH_LOCAL_KEYFILE}.pub" > "${_CHROOT_ROOT}/.ssh/authorized_keys"
chmod 600 "${_CHROOT_ROOT}/.ssh/authorized_keys"

# Creating box's default user own key
assure_box_sshkey "${_HOSTNAME}"

# Update sshd settings
echo_debug "SSH_PASSWORD_AUTHENTICATION: ${_SSH_PASSWORD_AUTHENTICATION} "

sed -i "s/^#*PasswordAuthentication\s\+.*$/\PasswordAuthentication ${_SSH_PASSWORD_AUTHENTICATION}/" "${_CHROOT_ROOT}/etc/ssh/sshd_config"

sed -i "s|^#Port 22|Port 2222|s" "${_CHROOT_ROOT}/etc/ssh/sshd_config"

sed -i 's/^#*ChallengeResponseAuthentication\s\+.*$/\ChallengeResponseAuthentication no/' "${_CHROOT_ROOT}/etc/ssh/sshd_config"

sed -i 's/^#*PubkeyAuthentication\s\+.*$/\PubkeyAuthentication yes/' "${_CHROOT_ROOT}/etc/ssh/sshd_config"
sed -i 's|^#*AuthorizedKeysFile\s\+.*$|\AuthorizedKeysFile .ssh/authorized_keys|' "${_CHROOT_ROOT}/etc/ssh/sshd_config"
