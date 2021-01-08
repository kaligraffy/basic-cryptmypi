# basiccryptmypi
basiccryptmypi - A really simple kali pi build script.
With thanks to unixabg for the original script.

THIS IS A WORK IN PROGRESS, DON'T DOWNLOAD UNLESS YOU ARE PREPARED TO TROUBLESHOOT

PLEASE READ THIS BEFORE YOU USE THE SCRIPT.

USAGE

Leave aside about 30GB of disk space 

Modify .env with your settings. At the least change:
export _OUTPUT_BLOCK_DEVICE="/dev/sdX"
export _LUKS_PASSWORD="CHANGEME"
export _ROOT_PASSWORD="CHANGEME"
export _KALI_PASSWORD="CHANGEME"
export _SSH_KEY_PASSPHRASE="CHANGEME"
export _WIFI_PASSWORD='CHANGEME'
export _IMAGE_SHA256="c6ceee472eb4dabf4ea895ef53c7bd28751feb44d46ce2fa3f51eb5469164c2c"
export _IMAGE_URL="https://images.kali.org/arm-images/kali-linux-2020.4-rpi4-nexmon-64.img.xz"

Un/Comment anything in functions extra_setup() and extra_extra_setup().

Run: 
- change directory to cryptmypi directory
- sudo ./cryptmypi
- follow prompts

PURPOSE

Creates a configurable kali sd card or usb for the raspberry pi with strong encryption as default. The following 
options should be descriptive enough, but look in options.sh for what each one does:

initramfs_wifi_setup
wifi_setup
boot_hash_setup
display_manager_setup
dropbear_setup
luks_nuke_setup
ssh_setup
cpu_governor_setup
hostname_setup
dns_setup
root_password_setup
user_password_setup
vpn_client_setup
firewall_setup
clamav_setup
fake_hwclock_setup
apt_upgrade
docker_setup
packages_setup
aide_setup
snapper_setup
ntpsec_setup
iodine_setup
vlc_setup
firejail_setup
sysctl_hardening_setup
mount_boot_readonly_setup
passwordless_login_setup
set_default_shell_zsh
bluetooth_setup
apparmor_setup
random_mac_on_reboot_setup

Testing is 'ad hoc' and only for the RPI4. Oher kernels might work if set in env.sh

ISSUES

Occasionally, the mounts don't get cleaned up properly, if this is the case run: losetup -D; umount /dev/loop/*; mount
Then check if there are any other mounts to umount.

TODO
- re-comment the .env file for the less obvious environment variables
- use BATS to test the script
- TEST initramfs wifi, ssh and dropbear work together
- SSH defaults
- sysctl hardening against lynis
- apparmor/firejail support
- incorrect fstab settings for btrfs (last digit should be 0 for no fsck (tbc)
- no assessment of noload being taken out of cmdline.txt for ext4 filesystems (may cause additional writes
- duplicate entries in crypttab in the initramfs by script
- fix unmount logic
- non-kali images
- investigate cgroups logic in docker_setup, see if it's still required
- clean up some of the code, thoroughly test it
- build own image from scratch?

HOW DOES IT WORK

1. The script downloads the image using the URL specified in the .env file (if it's already there it skips downloading it)
2. Then it extracts the image (if it's already there it asks if you want to re-extract)
3. Then it copies the contents to a directory called 'root' in the build directory
4. Then it runs the normal configuration 
5. Then it runs the custom configuration specified in .env (in function extra_setup)
6. Finally, it creates an encrypted disk and writes the build to it

LOGGING

The script logs to the cryptmypi directory, making a log of all actions to the file specified in the .env file.
