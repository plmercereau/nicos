{
  imports = [
    ./fleet
    ./fs
    ./git
    ./impermanence
    ./kubernetes
    ./local-server
    ./lib
    ./networking
    ./nix
    ./nix-builder
    ./programs
    ./prometheus
    ./ssh
    ./swap
    ./time
    ./users
  ];
  system.stateVersion = "23.11";
}
