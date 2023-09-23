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
    homebrew.casks =
      [
        "bitwarden"
        "dropbox"
      ]
      ++ (
        optionals applications.communication.enable
        [
          "skype"
          "whatsapp"
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
          "battle-net" # TODO not working
        ]
      );
  };
}
