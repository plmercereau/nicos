{
  lib,
  pkgs,
  ...
}: let
  isLinux = pkgs.hostPlatform.isLinux;
  isDarwin = pkgs.hostPlatform.isDarwin;
in {
  imports = [
    ./pilou.nix
    ./alacritty.nix
    ./editors/vscode.nix
  ];

  programs.helix.defaultEditor = lib.mkForce false;

  home.packages = with pkgs;
    [
      spotify
      zoom-us
      dbeaver
      qbittorrent
    ]
    ++ lib.optionals isLinux [
      google-chrome
    ]
    ++ lib.optionals isDarwin [
      utm
      iina
      teams # not working on Linux
    ];

  # Works both with Gnome and MacOS
  programs.zsh.dirHashes = {
    desk = "$HOME/Desktop";
    dl = "$HOME/Downloads";
    docs = "$HOME/Documents";
    vids = "$HOME/Videos";
  };
}
