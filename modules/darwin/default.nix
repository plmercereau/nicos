{
  config,
  options,
  lib,
  pkgs,
  ...
}:
with lib; {
  # "fonts" renamed to "packages" in nixos, but not in nix-darwin
  options.fonts.packages = options.fonts.fonts;
}
