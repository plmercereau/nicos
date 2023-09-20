{config, ...}: {
  settings.hardware = config.settings.hardwares.x86-hetzner;
  settings.profile = config.settings.profiles.basic;
  settings.server.enable = true;

  systemd.network.networks."10-wan".address = [
    "128.140.39.64"
  ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/8f10208d-bc07-4801-bfa5-81a68fb216c1";
    fsType = "ext4";
  };

  swapDevices = [
    {device = "/dev/disk/by-uuid/87f505c2-65b4-4154-b301-b0ec80a80e06";}
  ];
}
