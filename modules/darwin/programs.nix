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
      # TODO install Office 365
      # Do not use brew to make sure we're using the latest version of WhatsApp
      "WhatsApp Messenger" = 310633997;
      OneDrive = 823766827;
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
