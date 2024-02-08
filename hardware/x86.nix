{
  lib,
  config,
  modulesPath,
  ...
}: {
  nixpkgs.hostPlatform = "x86_64-linux";
  imports = [./common.nix];
}
