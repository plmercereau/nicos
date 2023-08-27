{ pkgs, ... }:
{
  # Common config for every machine (NixOS or Darwin)
  environment.systemPackages = with pkgs;
    [
      git
      tmux
    ];
}
