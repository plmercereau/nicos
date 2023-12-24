{
  config,
  lib,
  pkgs,
  ...
}: {
  services = {
    # https://man7.org/linux/man-pages/man8/fstrim.8.html
    fstrim.enable = true;

    # Avoid pulling in unneeded dependencies
    udisks2.enable = lib.mkDefault false;
  };
}
