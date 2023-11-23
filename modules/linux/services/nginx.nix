{
  config,
  modulesPath,
  pkgs,
  lib,
  ...
}: let
  cfg = config.services.nginx;
in {
  config = lib.mkIf cfg.enable {
    # TODO configure firefox+chrome+safari to directly access to "hostname" without "http://": https://support.mozilla.org/en-US/questions/1390183
    networking.firewall.allowedTCPPorts = [80 443];

    services.nginx = {
      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;
      recommendedProxySettings = true;
    };
  };
}
