{ pkgs, ... }:
{
  nixpkgs.config.allowUnfree = true;

  # Common config for every machine (NixOS or Darwin)
  environment.systemPackages = with pkgs;
    [
      # TODO zero2 does not need so many packages
      # * 4.3GB -> 4.7GB
      curl
      e2fsprogs
      file
      git
      jq
      jq
      killall
      nnn # file browser
      speedtest-cli # Command line speed test utility
      tmux
      unzip
      wget
    ];

  programs.zsh.enable = true;
  # * Required for zsh completion, see: https://nix-community.github.io/home-manager/options.html#opt-programs.zsh.enableCompletion
  environment.pathsToLink = [ "/share/zsh" ];

  environment.shells = with pkgs; [ bashInteractive zsh ];

}
