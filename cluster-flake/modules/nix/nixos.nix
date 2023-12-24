{
  config,
  lib,
  pkgs,
  ...
}: {
  nix = {
    package = pkgs.nixFlakes;

    # Required for deploy-rs to work, see https://github.com/serokell/deploy-rs/issues/25
    settings.trusted-users = ["@wheel"];
    extraOptions =
      lib.optionalString (config.nix.package == pkgs.nixFlakes)
      "experimental-features = nix-command flakes";
  };

  # Run unpatched dynamic binaries on NixOS.
  programs.nix-ld.enable = true;
}
