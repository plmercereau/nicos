#!/usr/bin/env nu

# let DEVICE=/dev/disk4
# let TARGET=pi4g
# * The mount command is different on macOS. This script uses Paragon ExtFS (not free)
# let MOUNT_CMD="/usr/local/sbin/mount_ufsd_ExtFS"
let $MOUNT_CMD = "/usr/local/sbin/mount_ufsd_ExtFS"

def main [
    device: string
    _host?: string] {

    # TODO not ideal way to determine which host is a raspberry pi. Find a better way.
    # * We could get the list from an evaluation of the flake
    let isRaspberryPi = {|x| open $x | $in =~ '\.\.\/hardware\/(pi4|zero2)\.nix' }
    let $hosts = (ls hosts/*.nix | get name | filter $isRaspberryPi | path basename | str replace ".nix" "")

    let $host = ($_host | default ($hosts | input list) )

    # * Generate ed25519 private and public keys into a temporary directory
    let $tempKeys = (mktemp -d)
    ssh-keygen -t ed25519 -N '' -C '' -f $"($tempKeys)/ssh_host_ed25519_key" | str join
    let $publicKey = open $"($tempKeys)/ssh_host_ed25519_key.pub" | str trim

    # * Add the public key to the machine config
    open $"hosts/($host).json" | upsert sshPublicKey $publicKey | save -f $"hosts/($host).json"
    
    # * Rekey the Agenix secrets
    agenix --rekey

    # * Build image
    nix build $".#nixosConfigurations.($host).config.system.build.sdImage" --no-link --print-out-paths
    let $imageFile = (nix build $".#nixosConfigurations.($host).config.system.build.sdImage" --no-link --print-out-paths) + $"/sd-image/($host).img"

    # * Make sure the SD card is not mounted
    do { sudo umount $"($device)*" } | complete

    # * Copy image to the SD card
    sudo dd $"if=($imageFile)" $"of=($device)" bs=1M conv=fsync status=progress

    # * Move the key files to the SD card
    let $osPartition = (ls $"($device)*" | get name | sort | last)
    let $tempMount = (mktemp -d)
    
    # * Make sure the SD card is not mounted
    do { sudo umount $"($device)*" } | complete

    exec $"sudo ($MOUNT_CMD) ($osPartition) ($tempMount)"
    sudo mkdir -p $"($tempMount)/etc/ssh"
    sudo mv $"(tempKeys)/*" $"($tempMount)/etc/ssh"
    sudo chmod 600 $"($tempMount)/etc/ssh/ssh_host_ed25519_key"
    sudo chmod 644 $"($tempMount)etc/ssh/ssh_host_ed25519_key.pub"

    # * Clean up: Unmount the SD card
    do { sudo umount $"($device)*" } | complete

    # * Clean up: Remove the temporary directory that contains the SSH keys
    rm -rf ($tempKeys)
    }




# # * Add the public key to the machine config
# PUBLIC_KEY=$(cat /tmp/ssh_host_ed25519_key.pub | awk '{$1=$1};1') # Trim whitespace
# echo "$( jq --arg key "$PUBLIC_KEY" '.sshPublicKey = $key' hosts/$TARGET.json )" > hosts/$TARGET.json

# # * Rekey the Agenix secrets
# agenix -r

# # * Build image
# IMAGE=$(nix build .#nixosConfigurations.$TARGET.config.system.build.sdImage --no-link --print-out-paths)/sd-image/$TARGET.img

# # * Make sure the SD card is not mounted
# sudo umount $DEVICE* 2>/dev/null 

# # * Copy image to the SD card
# sudo dd if=$IMAGE of=$DEVICE bs=1M conv=fsync status=progress

# # * Move the key files to the SD card
# OS_PARTITION=$(ls $DEVICE* | sort | tail -1 | tr -d '\n')
# mkdir -p /tmp/sd-data
# sudo umount $OS_PARTITION 2>/dev/null 
# sudo $MOUNT_CMD $OS_PARTITION /tmp/sd-data
# sudo mkdir -p /tmp/sd-data/etc/ssh
# sudo mv /tmp/ssh_host_ed25519_key* /tmp/sd-data/etc/ssh/
# sudo chmod 600 /tmp/sd-data/etc/ssh/ssh_host_ed25519_key
# sudo chmod 644 /tmp/sd-data/etc/ssh/ssh_host_ed25519_key.pub

# # * Clean up: Unmount the SD card
# sudo umount $DEVICE* 2>/dev/null 

# echo "Don't forget to update your SSH known hosts in order to be able to connect to this machine"