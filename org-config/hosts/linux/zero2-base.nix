{
  config,
  pkgs,
  lib,
  ...
}: {
  settings.hardwarePlatform = config.settings.hardwarePlatforms.zero2;
  settings.profile = config.settings.profiles.minimal;
  settings.server.enable = true;

  swapDevices = [{device = "/dev/disk/by-label/SWAP";}];
}
