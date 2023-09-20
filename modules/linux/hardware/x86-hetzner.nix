{
  lib,
  options,
  config,
  modulesPath,
  pkgs,
  ...
}:
with lib; let
  platform = config.settings.hardware;
  platforms = config.settings.hardwares;
in {
  config = mkIf (platform == platforms.x86-hetzner) {
    boot.loader.grub.enable = true;
    boot.loader.grub.device = "/dev/sda";
    boot.initrd.availableKernelModules = ["ata_piix" "virtio_pci" "virtio_scsi" "xhci_pci" "sd_mod" "sr_mod"];
    boot.initrd.kernelModules = [];
    boot.kernelModules = [];
    boot.extraModulePackages = [];

    systemd.network.enable = true;

    # * See: https://github.com/NixOS/nixpkgs/issues/180175
    systemd.services.NetworkManager-wait-online.enable = lib.mkForce false;
    systemd.services.systemd-networkd-wait-online.enable = lib.mkForce false;

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
