{lib, ...}: {
  imports = [
    ./common.nix
    ./alacritty.nix
    ./editors/vscode.nix
  ];
  programs.helix.defaultEditor = lib.mkForce false;
}
