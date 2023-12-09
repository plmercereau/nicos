# Next
## Flakification
### Fix nushell scripts
### Time to split lib flake vs user flake?
### read root path, users/hosts paths, wifi secret path, cluster admins from a TOML/nix config file
### Unify flakes/machines.nix and flakes/main.nix
### Unify flakes/main.nix and flakes/lib.nix
### Define hardware as modules
### flake CLI (get some inspiration from other flakes e.g. deploy-rs or agenix)

## sync script and cron for ~dev
send to onedrive, but online only
launchd/systemd

## on Fennec, but an archive "sink": everything that is put in an "archive" directory is moved to the common onedrive

## Remote builders

## Fix wireguard?
On darwin, need to `sudo wg-quick up wg0` after a start

## Tmux colours

## Wireguard inconsistency
On NixOS:
ping machine == ping machine.home

On Darwin:
ping machine != ping machine.home
machine -> wireguard
machine.home -> router DNS

# Later

## CLI tools
https://github.com/ajeetdsouza/zoxide
https://github.com/dandavison/delta
fish vs zsh? https://fishshell.com
https://www.jetbrains.com/lp/mono/
https://github.com/burntsushi/ripgrep
https://github.com/extrawurst/gitui

## Skhd is not working with MacOS Ventura

https://github.com/koekeishiya/skhd/issues/278

## Raspberry Pi OTG

Inspiration: https://git.sr.ht/~c00w/useful-nixos-aarch64/tree/master/item/pi4bgadget/config.nix

## Make `config.txt` work after building the sd image

https://nixos.wiki/wiki/NixOS_on_ARM/Raspberry_Pi#Notes_about_the_boot_process
https://github.com/NixOS/nixpkgs/pull/241534

## fn keys don't work on Puffin

## Restrict passwordless sudo to deploy-rs

## Warning with Darwin

https://discourse.nixos.org/t/how-do-i-define-lib-modules-defaultoverridepriority-in-configuration-nix/30371/2

git config --global init.defaultBranch main

## Annoying warning

not fixed yet:
https://discourse.nixos.org/t/warning-optionsdocbook-is-deprecated-since-23-11-and-will-be-removed-in-24-05/31353/3

## Yabai

- force Safari to space 2
- rename `wm.nix` to `display-manager.nix`
- Inspiration from https://github.com/kclejeune/system
- vscode starts in space 3
- whatsapp and spotify starts in space 5, spotify on the right, whatsapp on the left
- Mail/Calendar starts in screen 1/space 6 or screen 2/space 1
