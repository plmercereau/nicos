{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.settings.services.time;
in {
  options.settings.services.time = {
    enable = mkOption {
      description = "Enable timesyncd and htpdate.";
      type = types.bool;
      default = true;
    };
  };

  config.services = mkIf cfg.enable {
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
}
