{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  applications = config.settings.applications;
in {
  config = {
    homebrew.masApps = {
      "WhatsApp Messenger" = 310633997; # Do not use brew to make sure we're using the latest version
      OneDrive = 823766827;
      "Microsoft Word" = 462054704;
      "Microsoft Excel" = 462058435;
      "Microsoft PowerPoint" = 462062816;
    };

    homebrew.casks = [
      "bitwarden"
      "jellyfin-media-player"
      "raycast" # Raycast is a replacement of Spotlight that manages the launch of apps installed with nix
      "transmission-remote-gui"
    ];

    environment.systemPackages = with pkgs; [
      mas
    ];
  };
}
