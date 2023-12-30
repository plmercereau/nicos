{
  aarch64 = {
    label = "Generic aarch64";
    path = ./aarch64.nix;
  };
  x86 = {
    label = "Generic x86";
    path = ./x86.nix;
  };
  hetzner-arm = {
    label = "Hetzner Cloud ARM";
    path = ./hetzner-arm.nix;
  };
  hetzner-x86 = {
    label = "Hetzner Cloud x86";
    path = ./hetzner-x86.nix;
  };
  nuc = {
    label = "Intel NUC";
    path = ./nuc.nix;
  };
  raspberrypi-4 = {
    label = "Raspberry Pi 4";
    path = ./raspberrypi-4.nix;
  };
  raspberrypi-zero2w = {
    label = "Raspberry Pi Zero 2 W";
    path = ./raspberrypi-zero2w.nix;
  };
}
