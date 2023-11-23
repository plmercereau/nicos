#!/usr/bin/env nu
use lib.nu [save_secret, generate_ssh_keys, input_rule, input_required, input_ip] 

def main [name?: string] {
    let $hosts = ls hosts/*.json | get name | path basename | str replace ".json" ""
    let id = (ls hosts/*.json | get name | each {|x| open $x | get id } | sort | last | into int | $in + 1) 

    let name_validation = { |name| not (($name | is-empty) or ($name in $hosts)) }
    let $name = if (do $name_validation $name) { $name } else { input_rule $name_validation "Enter the name of the machine: " "Invalid name or already exists" }

    let options = [
        { label: "Mac OSX", import: null, platform: "x86_64-darwin"},
        { label: "Raspberry Pi 4", import: "pi4", platform: "aarch64-linux"},
        { label: "Raspberry Pi Zero 2w", import: "zero2", platform: "aarch64-linux"},
        { label: "Hetzner (x86)", import: "hetzner-x86", platform: "x86_64-linux"},
        { label: "NUC", import: "nuc", platform: "x86_64-linux"},
    ]

    let $hardware = $options | get label | input list "Select the hardware type" 
    
    let $option =  $options | filter {|x| $x.label == $hardware } | first

    let $modules = [ "Bastion" ] | input list --multi "Select modules to activate"
    let $publicIP = if "Bastion" in $modules { input_ip "Enter the public IP: " --required=true } else { null }
    
    let $localIP = (input_ip "Enter the local IP: ")
    {
        id: $id
        platform: $option.platform
        localIP: $localIP
        publicIP: $publicIP
        wg: {}
    }  | if "Bastion" in $modules {insert wg.server {enable: true, port: 51820}} else {$in} | to json | save $"hosts/($name).json"
    
    $'{config, ...}: {
    (if $option.import != null {$"imports = [../hardware/($option.import).nix];\n"})
}' | save $"hosts/($name).nix"

    # * generate the ssh private/public key pair
    generate_ssh_keys $name $"./ssh_($name)_ed25519_key"

    # * generate the wireguard private/public key pair
    let $wg_private_key = (wg genkey)
    save_secret $"./hosts/($name).wg.age" $wg_private_key
    let $wg_public_key = $wg_private_key | wg pubkey
    open $"hosts/($name).json" | upsert wg.publicKey $wg_public_key | to json | save --force $"hosts/($name).json"
    
}
