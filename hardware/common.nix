{
  lib,
  config,
  modulesPath,
  ...
}: {
  nix.settings.cores = lib.mkDefault 4; # Arbitrary number of cores
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.availableKernelModules = ["xhci_pci" "thunderbolt" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod"];
  boot.initrd.kernelModules = [];
  boot.extraModulePackages = [];

  # TODO make it consistent with a nixos-anywhere / disko config
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
  };
}
