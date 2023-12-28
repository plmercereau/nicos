{
  pkgs,
  hardware,
  ...
}: {
  imports = [hardware.m1];
  settings = {
    id = 2;
    sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKcwa/PgM3iOEzPdIfLwtpssHtozAzhU4I0g4Iked/LE";
    networking = {
      localIP = "10.136.1.242";
      vpn = {
        enable = true;
        publicKey = "zNzpca0ysOu3hf7BMahAs8B7Ii7LpBwHcOYaqacG1y8=";
      };
    };
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
    # "paragon-extfs" # TODO not working
  ];

  homebrew.masApps = {
    "HP Smart for Desktop" = 1474276998;
  };

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
