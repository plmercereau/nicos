{pkgs, ...}: {
  imports = [
    ./networking
    ./services
    ./cluster.nix
    ./host.nix
    ./lib.nix
    ./programs.nix
    ./ui.nix
    ./users.nix
  ];
}
