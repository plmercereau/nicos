{
  lib,
  options,
  config,
  modulesPath,
  pkgs,
  ...
}:
with lib; let
  hostName = config.networking.hostName;
in {
  imports = [
    ./sd-image.nix
    (modulesPath + "/installer/sd-card/sd-image-aarch64.nix")
  ];

  nixpkgs.hostPlatform = "aarch64-linux";

  sdImage = {
    # bzip2 compression takes loads of time with emulation, skip it. Enable this if you're low on space.
    compressImage = false;
    imageName = "${hostName}.img";

    swap.enable = true;
    swap.size = 2048;
  };

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
}
