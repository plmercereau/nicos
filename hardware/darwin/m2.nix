{
  lib,
  config,
  modulesPath,
  ...
}: {
  nixpkgs.hostPlatform = "aarch64-darwin";
  nix.settings.cores = 10;
}
