{pkgs, ...}: {
  settings = {
    windowManager.enable = true;
    keyMapping.enable = true;

    applications = {
      communication.enable = true;
      development.enable = true;
      games.enable = true;
      music.enable = true;
      office.enable = true;
    };
  };

  homebrew.casks = [
    "supertuxkart" # for kids
    "zwift"
    "goldencheetah"
    # "paragon-extfs" # TODO Error: Not upgrading 1 `installer manual` cask.
    # "onedrive" # TODO install from app store
  ];

  homebrew.masApps = {
    "HP Smart for Desktop" = 1474276998;
  };

  environment.systemPackages = [pkgs.mas]; # TODO everywhere

  home-manager.users.pilou = {
    imports = [../home-manager/pilou-gui.nix];

    home.packages = with pkgs; [
      discord
      gimp
    ];

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
