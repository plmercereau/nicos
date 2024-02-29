{pkgs, ...}: {
  imports = [
    ./fleet
    ./fs.nix
    ./git
    ./impermanence.nix
    ./kubernetes
    ./local-server
    ./lib.nix
    ./networking.nix
    ./nix.nix
    ./nix-builder.nix
    ./prometheus
    ./ssh.nix
    ./swap.nix
    ./time.nix
    ./users.nix
  ];
  system.stateVersion = "23.11";

  programs.bash.enableCompletion = true;

  # Packages that should always be available for manual intervention
  environment.systemPackages = with pkgs; [curl e2fsprogs];
}
