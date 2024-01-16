{
  config,
  lib,
  pkgs,
  ...
}: {
  nix = {
    settings = {
      max-jobs = lib.mkDefault config.nix.settings.cores; # use all cores
      # https://nixos.wiki/wiki/Storage_optimization
      auto-optimise-store = true;
      trusted-public-keys = ["devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="];
      trusted-substituters = ["https://devenv.cachix.org"];
    };
    # https://nixos.wiki/wiki/Distributed_build
    distributedBuilds = true;
    # optional, useful when the builder has a faster internet connection than yours
    extraOptions = ''
      builders-use-substitutes = true
    '';
  };
}
