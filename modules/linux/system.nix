{
  config,
  lib,
  pkgs,
  options,
  ...
}:
with lib; {
  config = {
    # This value determines the NixOS release with which your system is to be
    # compatible, in order to avoid breaking some software such as database
    # servers. You should change this only after NixOS release notes say you
    # should.
    system.stateVersion = "23.05"; # Did you read the comment?

    nix = {
      package = pkgs.nixFlakes;
      extraOptions =
        lib.optionalString (config.nix.package == pkgs.nixFlakes)
        "experimental-features = nix-command flakes";
    };

    # ? move to common modules ?
    services = {
      # https://man7.org/linux/man-pages/man8/fstrim.8.html
      fstrim.enable = true;
      # # Avoid pulling in unneeded dependencies
      udisks2.enable = false;

      # NTP time sync.
      timesyncd = {
        enable = true;
        servers = mkDefault [
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
  };
}
