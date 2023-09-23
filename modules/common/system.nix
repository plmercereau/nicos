{pkgs, ...}: {
  nixpkgs.config.allowUnfree = true;

  # https://nixos.wiki/wiki/Storage_optimization
  nix.settings.auto-optimise-store = true;

  # https://nixos.wiki/wiki/Distributed_build
  nix.distributedBuilds = true;
}
