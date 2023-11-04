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

    # Pi Zero 2 struggles to work without swap
    swap.enable = true;
    swap.size = 1024;

    extraFirmwareConfig = {
      # Give up VRAM for more Free System Memory
      # - Disable camera which automatically reserves 128MB VRAM
      start_x = 0;
      # - Reduce allocation of VRAM to 16MB minimum for non-rotated (32MB for rotated)
      gpu_mem = 16;

      # Configure display to 800x600
      # * See: https://elinux.org/RPi_Configuration
      hdmi_group = 2;
      hdmi_mode = 8;

      # dtoverlay = "dwc2";
      # modules-load = "dwc2";
    };
  };
  hardware.enableRedistributableFirmware = true;

  boot = {
    # ? why linux_rpi4? Why not zero2 or rpi3 packages?
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