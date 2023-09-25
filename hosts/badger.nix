{
  pkgs,
  lib,
  config,
  flakeInputs,
  ...
}: {
  settings = {
    gui.windowManager.enable = true;
    applications = {
      communication.enable = true;
      development.enable = true;
      games.enable = true;
      music.enable = true;
      office.enable = true;
    };
  };

  homebrew.casks = [
    "zwift"
    "goldencheetah"
  ];

  home-manager.users.pilou = {
    imports = [
      ../home-manager/profile-gui.nix
    ];

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
