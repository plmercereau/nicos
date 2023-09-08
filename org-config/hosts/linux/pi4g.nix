{
  config,
  pkgs,
  lib,
  ...
}: {
  settings.hardwarePlatform = config.settings.hardwarePlatforms.pi4;
  # TODO dig further into this after wifi is working
  # TODO change once we understand the impact it has on console.enable
  settings.profile = config.settings.profiles.basic;
  settings.server.enable = true;

  swapDevices = [{device = "/dev/disk/by-label/SWAP";}];

  # TODO dig further into this after wifi is working
  console = {
    enable = true;
    earlySetup = true;
  };
}
