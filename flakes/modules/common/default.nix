{pkgs, ...}: {
  imports = [
    ./hosts.nix
    ./lib.nix
    ./programs.nix
    ./builder.nix
    ./ssh.nix
    ./ui.nix
    ./users.nix
    ./wireguard.nix
  ];
}
