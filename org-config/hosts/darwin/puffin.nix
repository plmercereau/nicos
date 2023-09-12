{
  pkgs,
  lib,
  config,
  flakeInputs,
  ...
}: {
  # TODO not m1
  settings.hardwarePlatform = config.settings.hardwarePlatforms.m1;

  # TODO configure the machine to be used as a remote builder

  homebrew.casks = [
    # TODO settings.applications.communication = true
    "skype"
    "whatsapp"
    "webex"
    "zoom"
    "skype-for-business"

    # TODO settings.applications.music = true;
    "sonos"

    # TODO settings.applications.dev = true;
    "docker"
    "balenaetcher"

    # Other
    "google-chrome"
    "notion"
    "steam"
    "zwift"
  ];

  home-manager.users.pilou = {
    home.packages = with pkgs; [
      adguardhome
      # TODO settings.applications.music = true;
      spotify
      # TODO settings.applications.communication = true
      teams
    ];

    programs.alacritty.enable = true;

    programs.zsh.dirHashes = {
      config = "$HOME/dev/plmercereau/nix-config";
      desk = "$HOME/Desktop";
      dev = "$HOME/dev";
      dl = "$HOME/Downloads";
      docs = "$HOME/Documents";
      gh = "$HOME/dev/plmercereau";
      vids = "$HOME/Videos";
      ec = "$HOME/Documents/EC";
    };
  };
}
