{
  # TODO configure the machine to be used as a remote builder
  settings = {
    windowManager.enable = true;
    keyMapping.enable = true;
  };

  homebrew.casks = [
    "arduino"
    "balenaetcher"
    "docker"
    "google-chrome" # nix package only for linux
    "grammarly-desktop"
    "grammarly"
    "notion"
    "skype-for-business"
    "skype"
    "sonos"
    "webex"
    "zwift"
  ];

  home-manager.users.pilou = {
    imports = [../home-manager/pilou-gui.nix];

    programs.zsh.dirHashes = {
      config = "$HOME/dev/plmercereau/nix-config";
      dev = "$HOME/dev";
      gh = "$HOME/dev/plmercereau";
    };
  };
}
