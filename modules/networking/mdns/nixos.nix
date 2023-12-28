{
  config,
  lib,
  pkgs,
  ...
}: {
  services = {
    # mDNS
    avahi.enable = true;
  };
}
