{pkgs, ...}: {
  nixpkgs.config.allowUnfree = true;

  # https://nixos.wiki/wiki/Storage_optimization
  nix.settings.auto-optimise-store = true;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
  };
}
