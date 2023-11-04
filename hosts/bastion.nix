{config, ...}: let
  hosts = config.settings.hosts;
  host = hosts."${config.networking.hostName}";
in {
  imports = [../hardware/x86-hetzner.nix];

  settings.wireguard.server.externalInterface = "ens3";

  settings.profile = config.settings.profiles.basic;
  settings.server.enable = true;

  systemd.network.networks."10-wan".address = [host.ip];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/77ed390d-f8c2-4ade-999a-920fe10c7f48";
    fsType = "ext4";
  };

  swapDevices = [
    {device = "/dev/disk/by-uuid/180c32a7-b231-4108-987b-c9e44c18d913";}
  ];
}
