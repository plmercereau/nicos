{pkgs, ...}: {
  imports = [
    ./system.nix
    ./hardware.nix
    ./lib.nix
    ./users.nix
    ./ui.nix
    ./bastion.nix
    ./programs.nix
  ];
}
