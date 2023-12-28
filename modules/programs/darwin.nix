{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  applications = config.settings.applications;
in {
  homebrew = {
    enable = true;

    global = {
      brewfile = true; # Run brew bundle from anywhere
      lockfiles = false; # Don't save lockfile (since running from anywhere)
    };

    onActivation = {
      autoUpdate = true; # update during rebuild on activation. can make darwin-rebuild much slower
      cleanup = "zap"; # Uninstall all programs not declared
      upgrade = true;
    };

    masApps = {
      "WhatsApp Messenger" = 310633997; # Do not use brew to make sure we're using the latest version
      OneDrive = 823766827;
      "Microsoft Word" = 462054704;
      "Microsoft Excel" = 462058435;
      "Microsoft PowerPoint" = 462062816;
    };

    casks = [
      "bitwarden"
      "jellyfin-media-player"
      "raycast" # Raycast is a replacement of Spotlight that manages the launch of apps installed with nix
    ];
  };

  environment.systemPackages = with pkgs; [
    mas
  ];
}
