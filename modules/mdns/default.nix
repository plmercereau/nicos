{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.settings.mdns;
in {
  options.settings.mdns = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable mDNS service (avahi).";
    };
  };

  config.services.avahi = mkIf cfg.enable {
    # mDNS
    enable = true;
    domainName = config.networking.domain;
  };
}
