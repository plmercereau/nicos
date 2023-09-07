{
  config,
  pkgs,
  lib,
  ...
}: {
  settings.hardwarePlatform = config.settings.hardwarePlatforms.pi4;
  settings.profile = config.settings.profiles.minimal;
  settings.server.enable = true;

  # TODO document why this is needed
  programs.nix-ld.enable = true;

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
}
