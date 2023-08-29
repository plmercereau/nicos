{pkgs, ...}: {
  imports = [
    ./hardware.nix
    ./home-manager
    ./lib.nix
    ./users.nix
    ./wm.nix
  ];

  # https://nixos.wiki/wiki/Storage_optimization
  nix.settings.auto-optimise-store = true;

  # https://nixos.wiki/wiki/Distributed_build
  nix.distributedBuilds = true;

  # Common config for every machine (NixOS or Darwin)
  environment.systemPackages = with pkgs; [
    git
    tmux
  ];

  programs.bash.enable = true;
  programs.bash.enableCompletion = true;

  programs.zsh.enable = true;
  # * Required for zsh completion, see: https://nix-community.github.io/home-manager/options.html#opt-programs.zsh.enableCompletion
  environment.pathsToLink = ["/share/zsh"];
}
