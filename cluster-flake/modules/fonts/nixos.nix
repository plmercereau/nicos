{pkgs, ...}: let
  fonts = import ./fonts.nix {inherit pkgs;};
in {
  fonts.fontDir.enable = true;
  fonts.packages = fonts;
}
