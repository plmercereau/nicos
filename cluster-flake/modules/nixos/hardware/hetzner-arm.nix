{
  lib,
  options,
  config,
  modulesPath,
  pkgs,
  srvos,
  ...
}: {
  nixpkgs.hostPlatform = "aarch64-linux";

  imports = [
    srvos.hardware-hetzner-cloud-arm
    ./hetzner.nix
  ];
}
