{pkgs, ...}: {
  imports = [
    ./system.nix
    ./hardware.nix
    ./home-manager
    ./lib.nix
    ./users.nix
    ./wm.nix
  ];
}
