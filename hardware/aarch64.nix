{
  lib,
  config,
  modulesPath,
  ...
}: {
  nixpkgs.hostPlatform = "aarch64-linux";
  imports = [./common.nix];
}
