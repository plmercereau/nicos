{
  lib,
  pkgs,
  ...
}: let
  isLinux = pkgs.hostPlatform.isLinux;
in {
  imports = [
    ./pilou.nix
    ./alacritty.nix
    ./editors/vscode.nix
  ];
  programs.helix.defaultEditor = lib.mkForce false;
  home.packages = with pkgs; ([
      qbittorrent
      iina
    ]
    ++ lib.optional isLinux [
      google-chrome
    ]);
}
