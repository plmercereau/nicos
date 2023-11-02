{config, ...}: {
  imports = [../hardware/x86-hetzner.nix];
  settings.bastion = {
    enable = true;
    user = {
      keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDMDKUL/WLaqQmbjPuRjShMjrYnux4P+aV+XO7CIhw5HULtHDC5LYp3vY10g3K0djrOqbq1AZQftZ2qcpH1EnnufZJz8tviO9YkXfdUFwLchXpkKQ+WVw7Ih5BKJ7hUO+b6kYYkGELN/9wMsFyjY0wFq2FZO+elwNbEfaCwDeYt0gl/Wz0K+ZXHil0ji+BrUZ/O+jnk+8okQbbb1sfpuZ3QH+/oGD1GtSg/aDbJncZbcf7fP95SIBWPvP+vjd/ft8tddgXOXBrvh0OM1LoaBx7WkNo/JAHyDDP7KD+3IXEEdU1LDsDxalCBm1xAy0M25AHwWPcsamihunaiRVHrSM0n"
      ];
    };
  };

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
