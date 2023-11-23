{
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./editors/helix.nix
    ./zsh
  ];

  home.stateVersion = lib.mkDefault "23.05";

  home.packages = with pkgs; [
    eza
  ];

  home.shellAliases = {
    l = "eza -la --git";
    la = "eza -a --git";
    ls = "eza";
    ll = "eza -l --git";
    lla = "eza -la --git";
  };

  # better wget
  programs.aria2 = {
    enable = true;
  };

  programs.bat = {
    enable = true;
    config.theme = "gruvbox-dark";
  };

  programs.dircolors.enable = true;

  programs.direnv = {
    # Direnv, load and unload environment variables depending on the current directory.
    # https://direnv.net
    # https://rycee.gitlab.io/home-manager/options.html#opt-programs.direnv.enable

    enable = true;
    # Zsh integration is manually enabled in zshrc in order to mute some of direnv's output
    enableZshIntegration = false;
    nix-direnv.enable = true;

    # devenv can be slow to load, we don't need a warning every time
    config.global.warn_timeout = "3m";
  };
}
