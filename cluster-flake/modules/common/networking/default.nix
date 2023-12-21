{pkgs, ...}: {
  imports = [
    ./network.nix
    ./ssh.nix
    ./wireguard.nix
  ];
}
