#!/usr/bin/env nu

# * The mount command is different on macOS. This script uses Paragon ExtFS (not free)
let $MOUNT_CMD = "/usr/local/sbin/mount_ufsd_ExtFS"

def unmount [device: string] {
    do { sudo umount $"($device)*" } | complete
}

def main [device: string # path to the SD card device 
] {

    # * Build the iso image
    let $image_file = (nix build $".#nixosConfigurations.($host).config.system.build.sdImage" --no-link --print-out-paths) + $"/sd-image/($host).img"

    # * Copy the image to the SD card
    unmount $device # First, make sure the SD card is not mounted
    sudo dd $"if=($image_file)" $"of=($device)" bs=1M conv=fsync status=progress

    # * Move the key files into the SD card
    unmount $device
    let $os_partition = (ls $"($device)*" | get name | sort | last)
    let $temp_mount = (mktemp --directory)
    sudo $MOUNT_CMD $os_partition $temp_mount
    sudo mkdir --parents $"($temp_mount)/etc/ssh"
    # Needed when using impermanence
    sudo mkdir --parents $"($temp_mount)/var/lib"
    sudo cp $private_key_path $"($temp_mount)/etc/ssh/ssh_host_ed25519_key"
    sudo chmod 600 $"($temp_mount)/etc/ssh/ssh_host_ed25519_key"
    sudo mv $"($private_key_path).pub" $"($temp_mount)/etc/ssh/ssh_host_ed25519_key.pub"
    sudo chmod 644 $"($temp_mount)/etc/ssh/ssh_host_ed25519_key.pub"

    # * Clean up: Unmount the SD card
    unmount $device
    rmdir $temp_mount

    echo "INFO: The private key is stored in the SD card. Make sure to keep it safe."
    echo "Don't forget to update your SSH known hosts through a local system rebuild in order to be able to connect to this machine."
}

