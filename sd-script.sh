#!/bin/sh
# TODO this script should be included in the justfile / taskfile
# TODO generate the wg keys
DEVICE=/dev/disk4
TARGET=pi4g

# * The mount command is different on macOS. This script uses Paragon ExtFS (not free)
MOUNT_CMD=/usr/local/sbin/mount_ufsd_ExtFS

# * Generate ed25519 private and public keys
ssh-keygen -t ed25519 -N '' -C '' -f /tmp/ssh_host_ed25519_key <<<y >/dev/null 

# * Add the public key to the machine config
PUBLIC_KEY=$(cat /tmp/ssh_host_ed25519_key.pub | awk '{$1=$1};1') # Trim whitespace
echo "$( jq --arg key "$PUBLIC_KEY" '.sshPublicKey = $key' hosts/$TARGET.json )" > hosts/$TARGET.json

# * Rekey the Agenix secrets
agenix -r

# * Build image
IMAGE=$(nix build .#nixosConfigurations.$TARGET.config.system.build.sdImage --no-link --print-out-paths)/sd-image/$TARGET.img

# * Make sure the SD card is not mounted
sudo umount $DEVICE* 2>/dev/null 

# * Copy image to the SD card
sudo dd if=$IMAGE of=$DEVICE bs=1M conv=fsync status=progress

# * Move the key files to the SD card
OS_PARTITION=$(ls $DEVICE* | sort | tail -1 | tr -d '\n')
mkdir -p /tmp/sd-data
sudo umount $OS_PARTITION 2>/dev/null 
sudo $MOUNT_CMD $OS_PARTITION /tmp/sd-data
sudo mkdir -p /tmp/sd-data/etc/ssh
sudo mv /tmp/ssh_host_ed25519_key* /tmp/sd-data/etc/ssh/
sudo chmod 600 /tmp/sd-data/etc/ssh/ssh_host_ed25519_key
sudo chmod 644 /tmp/sd-data/etc/ssh/ssh_host_ed25519_key.pub

# * Clean up: Unmount the SD card
sudo umount $DEVICE* 2>/dev/null 

echo "Don't forget to update your SSH known hosts in order to be able to connect to this machine"