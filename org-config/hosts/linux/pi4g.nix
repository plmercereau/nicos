{
  config,
  ...
}: {
  settings.hardwarePlatform = config.settings.hardwarePlatforms.pi4;
  settings.profile = config.settings.profiles.basic;
  settings.server.enable = true;
  swapDevices = [{device = "/dev/disk/by-label/SWAP";}];
}
