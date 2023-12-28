{pkgs, ...}: let
  fonts = import ./fonts.nix {inherit pkgs;};
in {
  # "fonts" renamed to "packages" in nixos, but not in nix-darwin
  fonts.fonts = fonts;
}
