{ modulesPath, ... }:
{
  imports = [
    ./pi4.nix
    ./sd-image.nix
    ./zero2.nix
    (modulesPath + "/installer/sd-card/sd-image-aarch64-installer.nix")
  ];
}
