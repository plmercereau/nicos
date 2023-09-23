{pkgs, ...}: {
  imports = [
    ./system.nix
    ./hardware.nix
    ./home-manager
    ./lib.nix
    ./users.nix
    ./ui.nix
    ./bastion.nix
    ./programs.nix
  ];
}
