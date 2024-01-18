{
  config,
  options,
  lib,
  pkgs,
  ...
}:
with lib; {
  options = {
    # "fonts" renamed to "packages" in nixos, but not in nix-darwin
    fonts.packages = options.fonts.fonts;
  };
}
