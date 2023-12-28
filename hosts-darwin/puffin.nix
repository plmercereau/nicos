{hardware, ...}: {
  imports = [hardware.x86];

  settings = {
    id = 3;
    sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG2l6Ve+Fzy5vd+S8WlolJftpFsQtXn7gsAfxHgEXOVH";
    networking = {
      localIP = "10.136.1.99";
      vpn = {
        enable = true;
        publicKey = "cMt59SZfO/YNKNfrcEzzGLTGpKoxH4g/0AR9Iu0eTnE=";
      };
    };
    services.nix-builder.enable = true;

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
