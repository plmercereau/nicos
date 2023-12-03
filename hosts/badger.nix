{pkgs, ...}: {
  settings = {
    windowManager.enable = true;
    keyMapping.enable = true;
  };

  homebrew.casks = [
    "arduino"
    "balenaetcher"
    "docker"
    "goldencheetah"
    "google-chrome" # nix package only for linux
    "grammarly-desktop"
    "grammarly"
    "notion"
    "skype-for-business"
    "skype"
    "sonos"
    "steam" # not available on nixpkgs
    "supertuxkart" # for kids
    "webex"
    "zwift"
    # "paragon-extfs" # TODO Error: Not upgrading 1 `installer manual` cask. => mac app store
  ];

  homebrew.masApps = {
    "HP Smart for Desktop" = 1474276998;
  };

  environment.systemPackages = with pkgs; [
    mas # TODO everywhere
  ];

  home-manager.users.pilou = {
    imports = [../home-manager/pilou-gui.nix];

    home.packages = with pkgs; [
      discord
      gimp
    ];

    programs.zsh.dirHashes = {
      config = "$HOME/dev/plmercereau/nix-config";
      dev = "$HOME/dev";
      gh = "$HOME/dev/plmercereau";
    };
  };
}
