{
  config,
  lib,
  pkgs,
  ...
}:
with lib; {
  nix = {
    package = pkgs.nixFlakes;

    settings = {
      max-jobs = mkDefault config.nix.settings.cores; # use all cores
      # https://nixos.wiki/wiki/Storage_optimization
      auto-optimise-store = true;
      # Required for deploy-rs to work, see https://github.com/serokell/deploy-rs/issues/25
      trusted-users = ["@wheel"];
      trusted-public-keys = ["devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="];
      trusted-substituters = ["https://devenv.cachix.org"];
    };
    # https://nixos.wiki/wiki/Distributed_build
    distributedBuilds = true;
    # optional, useful when the builder has a faster internet connection than yours
    extraOptions = ''
      builders-use-substitutes = true
      ${optionalString (config.nix.package == pkgs.nixFlakes)
        "experimental-features = nix-command flakes"}
    '';
  };
  # Run unpatched dynamic binaries on NixOS.
  programs.nix-ld.enable = true;
}