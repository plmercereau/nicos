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

  programs.atuin.enable = true;
  # Sync, search and backup shell history
  # * Needs manual setup: atuin login + atuin sync. See: https://atuin.sh/docs
  # TODO automate this with an agenix secret
  # * See: https://haseebmajid.dev/posts/2023-08-12-how-sync-your-shell-history-with-atuin-in-nix/
  # create a nix home-manager activation script that runs atuin sync
  # key_path = ~/.local/share/atuin/key
  # login with for the "pilou" user with a key stored in an agenix secret

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

  programs.git = {
    enable = true;

    lfs.enable = true;
    extraConfig = {
      # user.signingKey = "DA5D9235BD5BD4BD6F4C2EA868066BFF4EA525F1";
      # commit.gpgSign = true;
      init.defaultBranch = "main";
      alias.root = "rev-parse --show-toplevel";
    };
    diff-so-fancy.enable = true;

    ignores = [
      "*~"
      ".DS_Store"
      ".direnv"
      "/direnv"
      "/direnv.test"
      ".AppleDouble"
      ".LSOverride"
      "Icon"
      "._*"
      ".DocumentRevisions-V100"
      ".fseventsd"
      ".Spotlight-V100"
      ".TemporaryItems"
      ".Trashes"
      ".VolumeIcon.icns"
      ".com.apple.timemachine.donotpresent"
      ".AppleDB"
      ".AppleDesktop"
      "Network Trash Folder"
      "Temporary Items"
      ".apdisk"
    ];
  };
}
