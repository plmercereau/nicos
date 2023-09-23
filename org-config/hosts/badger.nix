{
  pkgs,
  lib,
  config,
  flakeInputs,
  ...
}: {
  settings = {
    ui.windowManager.enable = true;
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
    home.packages = with pkgs; [
      discord
      gimp
    ];

    programs.alacritty.enable = true;

    programs.vscode.enable = true;

    # ! https://github.com/NixOS/nixpkgs/issues/232074
    # programs.neomutt.enable = true;

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
