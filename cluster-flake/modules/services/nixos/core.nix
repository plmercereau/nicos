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

    # mDNS
    avahi.enable = true;

    # NTP time sync.
    timesyncd = {
      enable = true;
      servers = lib.mkDefault [
        "0.nixos.pool.ntp.org"
        "1.nixos.pool.ntp.org"
        "2.nixos.pool.ntp.org"
        "3.nixos.pool.ntp.org"
        "time.windows.com"
        "time.google.com"
      ];
    };

    htpdate = {
      enable = true;
      servers = ["www.kernel.org" "www.google.com" "www.cloudflare.com"];
    };
  };
}
