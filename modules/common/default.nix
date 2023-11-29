{pkgs, ...}: {
  imports = [
    ./hosts.nix
    ./lib.nix
    ./programs.nix
    ./ssh.nix
    ./ui.nix
    ./users.nix
    ./wireguard.nix
  ];
}
