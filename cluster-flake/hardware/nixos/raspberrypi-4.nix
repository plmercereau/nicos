{
  lib,
  pkgs,
  ...
}: {
  imports = [./raspberry-pi.nix];

  hardware.enableRedistributableFirmware = true;
  boot.kernelPackages = pkgs.linuxKernel.packages.linux_rpi4;

  nix.settings.cores = lib.mkDefault 4;
}
