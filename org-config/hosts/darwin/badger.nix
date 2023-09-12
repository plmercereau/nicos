{
  pkgs,
  lib,
  config,
  flakeInputs,
  ...
}: {
  settings.hardwarePlatform = config.settings.hardwarePlatforms.m1;

  homebrew.casks = [
    # Available in NixOS but not in Darwin
    "bitwarden"
    "docker"
    "dropbox"
    "goldencheetah"
    "google-chrome"
    "notion"
    "skype"
    "steam"
    "webex"
    "whatsapp"
    "zoom"
    # "arduino"
    # "signal" # linux: signal-desktop

    # Not available at all
    "balenaetcher"
    "battle-net" # TODO not working
    "grammarly-desktop"
    "grammarly"
    "skype-for-business"
    "sonos"
    "zwift"
    # "cyberghost-vpn"
    # "steam"
  ];

  # TODO remove this once the bluetooth installer package is developed
  age.secrets.wifi-install = {
    file = ../../bootstrap/wifi.age;
    path = "/run/agenix/wifi-install";
    group = "admin";
    mode = "740";
  };

  home-manager.users.pilou = {
    home.packages = with pkgs; [
      # TODO set these packages globally, not per user
      # ? move to a pilou hm UI config in org-config/users.nix?
      # UI tools
      adguardhome
      discord
      gimp
      spotify
      teams

      # TODO settings.applications.dev = true (and ui = true)
      dbeaver
      postman
      # ? move to a pilou hm Darwin config in org-config/users.nix?
      # Only Darwin
      utm
    ];

    programs.alacritty.enable = true;

    programs.vscode.enable = true;

    # ! https://github.com/NixOS/nixpkgs/issues/232074
    # programs.neomutt.enable = true;

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
