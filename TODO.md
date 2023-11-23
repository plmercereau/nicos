# Next

## get rid of the "programs" module

## Impermanent setup for systems with sd cards

https://nixos.wiki/wiki/Impermanence

## Remote builders

## Read hosts config nixosConfigurations/darwinConfigurations and remove .json config

...but we still need the platform type -> move to hosts/nixos and hosts/darwin

# Later

## Skhd is not working with MacOS Ventura

https://github.com/koekeishiya/skhd/issues/278

## Raspberry Pi OTG

Inspiration: https://git.sr.ht/~c00w/useful-nixos-aarch64/tree/master/item/pi4bgadget/config.nix

## Make `config.txt` work after building the sd image

https://nixos.wiki/wiki/NixOS_on_ARM/Raspberry_Pi#Notes_about_the_boot_process
https://github.com/NixOS/nixpkgs/pull/241534

## get rid of deploy-rs?

https://discourse.nixos.org/t/deploy-nixos-configurations-on-other-machines/22940/19
But what happens if a deployment fails, for instance network config or user credentials?
-> better improve than getting rid of it, in order to keep the magic rollback feature

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
