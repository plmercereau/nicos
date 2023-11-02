{pkgs, ...}: {
  imports = [
    ./system.nix
    ./lib.nix
    ./users.nix
    ./ui.nix
    ./bastion.nix
    ./programs.nix
  ];
}
