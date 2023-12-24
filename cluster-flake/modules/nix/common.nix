{
  config,
  lib,
  pkgs,
  ...
}: {
  nix = {
    # https://nixos.wiki/wiki/Storage_optimization
    settings.auto-optimise-store = true;
    # https://nixos.wiki/wiki/Distributed_build
    distributedBuilds = true;
    # optional, useful when the builder has a faster internet connection than yours
    extraOptions = ''
      builders-use-substitutes = true
    '';
  };
}
