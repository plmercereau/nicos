#!/usr/bin/env nu

# * The mount command is different on macOS. This script uses Paragon ExtFS (not free)
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

    echo "Don't forget to update your SSH known hosts through a local system rebuild in order to be able to connect to this machine."
    }

