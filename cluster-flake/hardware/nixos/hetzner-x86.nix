{
  lib,
  options,
  config,
  modulesPath,
  pkgs,
  srvos,
  ...
}: {
  nixpkgs.hostPlatform = "x86_64-linux";

  imports = [
    srvos.hardware-hetzner-cloud
    ./hetzner.nix
  ];
}
