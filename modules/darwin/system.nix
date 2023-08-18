{ config, pkgs, lib, inputs, ... }:
with lib;
let
  platform = config.settings.hardwarePlatform;
  platforms = config.settings.hardwarePlatforms;
in
{

  nixpkgs.hostPlatform = mkIf (platform == platforms.m1) "aarch64-darwin";

  services.nix-daemon.enable = true; # Make sure the nix daemon always runs
  nix.package = pkgs.nixVersions.stable;
  nix.settings.cores = 0; # use all cores
  nix.settings.max-jobs = 10; # use all cores (M1 has 8, M2 has 10)
  nix.settings.trusted-users = [ "@admin" ];
  nix.settings.extra-experimental-features = [ "nix-command" "flakes" ];
  nix.settings.keep-outputs = true;
  nix.settings.keep-derivations = true;
  nix.configureBuildUsers = true; # Allow nix-darwin to build users

  # Create a Linux remote builder that works out of the box
  nix.linux-builder.enable = true;
  nix.linux-builder.maxJobs = 10; # use all cores (M1 has 8, M2 has 10)

  # ? create a home-manager module that would work on both darwin and linux
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  homebrew = {
    enable = true;
    # updates homebrew packages on activation,
    # can make darwin-rebuild much slower (otherwise i'd forget to do it ever though)
    onActivation.autoUpdate = true;
  };

  # TODO understand before activating
  #nix.settings.auto-optimise-store = true;
  # nix.distributedBuilds = true;
  # nix.nixPath = [{
  #   nixpkgs = "${inputs.nixpkgs-darwin.outPath}";
  #   nixpkgs-nixos = "${inputs.nixpkgs.outPath}";
  # }];

  #{
  #  systems = [ "aarch64-linux" "x86_64-linux" ];
  #  speedFactor = 2;
  #  supportedFeatures = [ "kvm" "big-parallel" ];
  #  sshUser = "ragon";
  #  maxJobs = 8;
  #  hostName = "192.168.65.7";
  #  sshKey = "/Users/ragon/.ssh/id_ed25519";
  #  publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUM4aG9teFlQZlk4bS9JQ2c2NVNWNU9Temp3eW1sNmxEMXhGNi9zWUxPQkY=";
  #}

  # TODO understand before activating
  # nix.extraOptions = ''
  #   builders-use-substitutes = true
  # '';

  # TODO understand all these options
  # * See: https://github.com/LnL7/nix-darwin/blob/master/tests/system-defaults-write.nix
  system.defaults = {
    # NSGlobalDomain.AppleShowAllExtensions = true;
    # NSGlobalDomain.InitialKeyRepeat = 25;
    # NSGlobalDomain.KeyRepeat = 4;
    # NSGlobalDomain.NSNavPanelExpandedStateForSaveMode = true;
    # NSGlobalDomain.PMPrintingExpandedStateForPrint = true;
    # NSGlobalDomain."com.apple.mouse.tapBehavior" = 1;
    # NSGlobalDomain."com.apple.trackpad.trackpadCornerClickBehavior" = 1;
    # dock.autohide = true;
    # dock.mru-spaces = false;
    # dock.show-recents = false;
    # dock.static-only = true;
    # dock.expose-animation-duration = 0.01;
    # finder.AppleShowAllExtensions = true;
    # finder.FXEnableExtensionChangeWarning = false;
    # loginwindow.GuestEnabled = false;
  };

}
