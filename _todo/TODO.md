# WIP

# Next

## get rid of python click and use argparse instead?

## move all options to `settings.*`?

- settings.services
- [x] settings.networking (publicIP, ssh key, etc)

## Create a flake "init" script

prompt questions using inquirer and generate the flake template

## Poach things from

- https://github.com/nix-community/srvos
- https://git.sr.ht/~r-vdp/resilientOS
  - https://git.sr.ht/~r-vdp/resilientOS/tree/master/item/modules/auto_shutdown.nix
  - https://git.sr.ht/~r-vdp/resilientOS/tree/master/item/modules/docker.nix
  - https://git.sr.ht/~r-vdp/resilientOS/tree/master/item/modules/live_system.nix
  - https://git.sr.ht/~r-vdp/resilientOS/tree/master/item/modules/maintenance.nix
  - https://git.sr.ht/~r-vdp/resilientOS/tree/master/item/modules/network.nix
  - https://git.sr.ht/~r-vdp/resilientOS/tree/master/item/modules/system.nix

## init new machines with nixos-anywhere and disko

- after create, suggest to install
- after install, suggest to update local machine and bastions
- before install, check if the machine is not installed already
- ssh <new-machine>:
  - bastions must be re-deployed after installing a machine:
    - to get the dns entry
    - to create the tunnel with the new machine (wg key is needed)
  - and/or ssh config must be updated in the local machine
  - in any case, maybe both ssh/dns config is too much. Use only DNS?
- Add a security to be sure to never re-install on a machine that is already deployed (unless using a `--force` flag)

## Additional secrets

the way it currently works, it is not possible to define additonal agenix secrets in ./secrets.nix

## Log/monitoring

- https://git.sr.ht/~r-vdp/resilientOS/tree/master/item/modules/prometheus.nix
- https://git.sr.ht/~r-vdp/resilientOS/tree/master/item/modules/zabbixagent.nix

## Documentation

## rsync -> rclone script and cron for ~dev

send to onedrive, but online only
launchd/systemd

## on Fennec, but an archive "sink": everything that is put in an "archive" directory is moved to the common onedrive

## Traefik instead of nginx?

https://git.sr.ht/~r-vdp/resilientOS/tree/master/item/modules/traefik.nix

## Fix Wireguard?

On darwin, need to `sudo wg-quick up wg0` after a start?

## Improve and automate the prompts when creating a new machine

## Wireguard inconsistency

On NixOS:
ping machine == ping machine.home

On Darwin:
ping machine != ping machine.home
machine -> Wireguard
machine.home -> router DNS

## Raspberry Pi OTG

Inspiration: https://git.sr.ht/~c00w/useful-nixos-aarch64/tree/master/item/pi4bgadget/config.nix

## build sd image without paragon extfs on Darwin

- https://www.uubyte.com/blog/how-to-read-or-write-ext4-usb-on-apple-m1-or-m2-mac/
  really? ext4fuse in write mode? probably bullshit
- https://github.com/HowellBP/ext4-on-macos-using-docker -> meh, problem of iso with multiple partitions

## Make `config.txt` work after building the sd image

https://nixos.wiki/wiki/NixOS_on_ARM/Raspberry_Pi#Notes_about_the_boot_process
https://github.com/NixOS/nixpkgs/pull/241534

# User config

## CLI tools

https://github.com/ajeetdsouza/zoxide
https://github.com/dandavison/delta
fish vs zsh? https://fishshell.com
https://www.jetbrains.com/lp/mono/
https://github.com/burntsushi/ripgrep
https://github.com/extrawurst/gitui
https://git.sr.ht/~r-vdp/resilientOS/tree/master/item/modules/packages.nix

## Skhd is not working with MacOS Ventura

https://github.com/koekeishiya/skhd/issues/278

## fn keys don't work on Puffin

## Yabai

- force Safari to space 2
- rename `wm.nix` to `display-manager.nix`
- Inspiration from https://github.com/kclejeune/system
- vscode starts in space 3
- whatsapp and spotify starts in space 5, spotify on the right, whatsapp on the left
- Mail/Calendar starts in screen 1/space 6 or screen 2/space 1

## Tmux colours
