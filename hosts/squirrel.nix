{
  settings = {
    applications = {
      communication.enable = true;
      music.enable = true;
    };
  };

  home-manager.users.pilou = {
    imports = [
      ../home-manager/profile-cli.nix
    ];

    # TODO add these defaults to the home-manager module (when with Darwin)
    programs.zsh.dirHashes = {
      desk = "$HOME/Desktop";
      dl = "$HOME/Downloads";
      docs = "$HOME/Documents";
      vids = "$HOME/Videos";
    };
  };
}
