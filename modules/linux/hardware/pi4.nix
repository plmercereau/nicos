{
  lib,
  options,
  config,
  modulesPath,
  ...
}:
with lib; let
  platform = config.settings.hardwarePlatform;
  platforms = config.settings.hardwarePlatforms;
in {
  config = mkIf (platform == platforms.pi4) {
    nixpkgs.hostPlatform = "aarch64-linux";
    hardware.enableRedistributableFirmware = true;

    boot = {
      kernelPackages = pkgs.linuxKernel.packages.linux_rpi4;
      initrd.availableKernelModules = ["xhci_pci" "usbhid" "usb_storage"];
      loader = {
        grub.enable = false;
        generic-extlinux-compatible.enable = true;
      };
    };

    fileSystems = {
      "/" = {
        device = "/dev/disk/by-label/NIXOS_SD";
        fsType = "ext4";
        options = ["noatime"];
      };
    };

    networking.wireless.enable = true;
  };
}
