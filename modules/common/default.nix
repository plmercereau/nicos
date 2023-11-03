{pkgs, ...}: {
  imports = [
    ./system.nix
    ./lib.nix
    ./users.nix
    ./ui.nix
    ./wireguard.nix
    ./programs.nix
  ];
}
