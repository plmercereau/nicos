{config, ...}: {
  settings.hardware = config.settings.hardwares.pi4;
  settings.profile = config.settings.profiles.basic;
  settings.server.enable = true;
  swapDevices = [{device = "/dev/disk/by-label/SWAP";}];
}
