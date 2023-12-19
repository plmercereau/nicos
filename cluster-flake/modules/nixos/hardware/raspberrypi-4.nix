{pkgs, ...}: {
  imports = [./raspberry-pi.nix];

  boot.kernelPackages = pkgs.linuxKernel.packages.linux_rpi4;
}
