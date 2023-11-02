{config, ...}: {
  imports = [../hardware/pi4.nix];
  settings.profile = config.settings.profiles.basic;
  settings.server.enable = true;
  swapDevices = [{device = "/dev/disk/by-label/SWAP";}];

  # services.adguardhome.enable = true;
  # services.adguardhome.mutableSettings = false;
}
