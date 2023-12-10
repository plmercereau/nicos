{pkgs, ...}: {
  imports = [
    ./builder.nix
    ./cluster.nix
    ./host.nix
    ./lib.nix
    ./network.nix
    ./programs.nix
    ./ssh.nix
    ./ui.nix
    ./users.nix
    ./wireguard.nix
  ];
}
