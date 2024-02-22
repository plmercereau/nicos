{
  imports = [
    ./fleet
    ./fs
    ./git
    ./impermanence
    ./kubernetes
    ./lib
    ./mdns
    ./networking
    ./nix
    ./nix-builder
    ./programs
    ./prometheus
    ./ssh
    ./swap
    ./time
    ./users
    ./vpn
    ./wifi
  ];
  system.stateVersion = "23.11";
}
