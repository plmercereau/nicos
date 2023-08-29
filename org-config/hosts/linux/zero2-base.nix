{
  config,
  pkgs,
  lib,
  ...
}: {
  settings.hardwarePlatform = config.settings.hardwarePlatforms.zero2;
  settings.profile = config.settings.profiles.minimal;
  settings.server.enable = true;

  boot = {
    # TODO rpi4 ok, but what about zero2?
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

  swapDevices = [{device = "/dev/disk/by-label/SWAP";}];
}
