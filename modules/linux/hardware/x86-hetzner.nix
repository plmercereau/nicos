{
  lib,
  options,
  config,
  modulesPath,
  pkgs,
  ...
}:
with lib; let
  platform = config.settings.hardwarePlatform;
  platforms = config.settings.hardwarePlatforms;
in {
  config = mkIf (platform == platforms.x86-hetzner) {
    nixpkgs.hostPlatform = "x86_64-linux";
    boot.loader.grub.enable = true;
    boot.loader.grub.device = "/dev/sda";
    boot.initrd.availableKernelModules = ["ata_piix" "virtio_pci" "virtio_scsi" "xhci_pci" "sd_mod" "sr_mod"];
    boot.initrd.kernelModules = [];
    boot.kernelModules = [];
    boot.extraModulePackages = [];

    systemd.network.enable = true;
    systemd.network.networks."10-wan" = {
      networkConfig.DHCP = "no";

      routes = [
        {routeConfig = {Destination = "172.31.1.1";};}
        {
          routeConfig = {
            Gateway = "172.31.1.1";
            GatewayOnLink = true;
          };
        }
      ];
    };
  };
}
