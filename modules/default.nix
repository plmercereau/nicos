{
  imports = [
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
    ./ssh
    ./swap
    ./time
    ./users
    ./vpn
    ./wifi
  ];
  system.stateVersion = "23.11";
}
