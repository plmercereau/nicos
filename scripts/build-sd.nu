#!/usr/bin/env nu

use lib.nu [generate_ssh_keys] 

# * The mount command is different on macOS. This script uses Paragon ExtFS (not free)
let $MOUNT_CMD = "/usr/local/sbin/mount_ufsd_ExtFS"

def main [
    device: string # path to the SD card device
    host?: string # machine name
    --private-key (-k): string # path of the private key file
    ] {
    # * Select the host from a list of available hosts, if not passed on as an argument
    # TODO not ideal way to determine which host is a raspberry pi. Find a better way.
    # (We could get the list from an evaluation of the flake)
    let is_raspberry_pi = {|x| open $x | $in =~ '\.\.\/hardware\/(pi4|zero2)\.nix' }
    let $hosts = (ls hosts/*.nix | get name | filter $is_raspberry_pi | path basename | str replace ".nix" "")
    mut $host = $host
    if ($host | is-empty) {
        $host = ($hosts | input list)
    } 

    let $private_key_path = $"./ssh_($host)_ed25519_key"
    let $public_key = (generate_ssh_keys $host $private_key_path)

    # * Build the iso image
    nix build $".#nixosConfigurations.($host).config.system.build.sdImage" --no-link --print-out-paths
    let $image_file = (nix build $".#nixosConfigurations.($host).config.system.build.sdImage" --no-link --print-out-paths) + $"/sd-image/($host).img"

    # * Copy the image to the SD card
    do { sudo umount $"($device)*" } | complete # First, make sure the SD card is not mounted
    sudo dd $"if=($image_file)" $"of=($device)" bs=1M conv=fsync status=progress

    # * Move the key files into the SD card
    let $os_partition = (ls $"($device)*" | get name | sort | last)
    let $temp_mount = (mktemp --directory)
    sudo $MOUNT_CMD $os_partition $temp_mount
    sudo mkdir --parents $"($temp_mount)/etc/ssh"
    sudo cp $private_key $"($temp_mount)/etc/ssh/ssh_host_ed25519_key"
    sudo chmod 600 $"($temp_mount)/etc/ssh/ssh_host_ed25519_key"
    sudo mv $public_key $"($temp_mount)/etc/ssh/ssh_host_ed25519_key.pub"
    sudo chmod 644 $"($temp_mount)etc/ssh/ssh_host_ed25519_key.pub"

    # * Clean up: Unmount the SD card
    do { sudo umount $"($device)*" } | complete

    echo "Don't forget to update your SSH known hosts through a local system rebuild in order to be able to connect to this machine."
    # TODO add a message about the private key file: either remove or store in a safe place
    }

