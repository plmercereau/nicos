{
  config,
  pkgs,
  lib,
  ...
}: {
  settings.hardwarePlatform = config.settings.hardwarePlatforms.pi4;
  settings.profile = config.settings.profiles.minimal;
  settings.server.enable = true;

  swapDevices = [{device = "dev/disk/by-label/SWAP";}];
}
