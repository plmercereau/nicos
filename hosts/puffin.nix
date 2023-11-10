{
  # TODO configure the machine to be used as a remote builder
  settings = {
    windowManager.enable = true;
    keyMapping.enable = true;
    applications = {
      communication.enable = true;
      development.enable = true;
      music.enable = true;
      office.enable = true;
    };
  };

  homebrew.casks = [
    "zwift"
  ];

  home-manager.users.pilou = {
    imports = [
      ../home-manager/profile-gui.nix
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
