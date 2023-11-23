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
      # Do not use brew to make sure we're using the latest version of WhatsApp
      "WhatsApp Messenger" = mkIf applications.communication.enable 310633997;
    };

    homebrew.casks =
      [
        "bitwarden"
        "dropbox"
        "thunderbird" # nix package only for linux # TODO why thunderbird instead of apple mail?
        "google-chrome" # nix package only for linux
      ]
      ++ (
        optionals applications.communication.enable
        [
          "skype"
          "webex"
          "skype-for-business"
        ]
      )
      ++ (
        optionals applications.development.enable
        [
          "google-chrome" # nix package only for linux
          "docker"
          "balenaetcher"
          "arduino"
        ]
      )
      ++ (
        optionals applications.music.enable
        ["sonos"]
      )
      ++ (
        optionals applications.office.enable
        [
          "grammarly-desktop"
          "grammarly"
          "notion"
        ]
      )
      ++ (
        optionals applications.games.enable
        [
          # Available in NixOS but not in Darwin
          "steam"
          # Not available at all
          # "battle-net" # TODO not working
        ]
      );
  };
}
