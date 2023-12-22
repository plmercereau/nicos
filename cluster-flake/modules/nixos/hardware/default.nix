{
  raspberrypi-4 = {
    description = "Raspberry Pi 4";
    path = ./raspberrypi-4.nix;
  };
  raspberrypi-zero2w = {
    description = "Raspberry Pi Zero 2 W";
    path = ./raspberrypi-zero2w.nix;
  };
  nuc = {
    description = "Intel NUC";
    path = ./nuc.nix;
  };
  hetzner-x86 = {
    description = "Hetzner Cloud x86";
    path = ./hetzner-x86.nix;
  };
  hetzner-arm = {
    description = "Hetzner Cloud ARM";
    path = ./hetzner-arm.nix;
  };
}
