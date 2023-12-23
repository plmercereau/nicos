{
  config,
  modulesPath,
  pkgs,
  lib,
  ...
}: let
  adguardPort = 3000;
  cfg = config.services.adguardhome;
  nginx = config.services.nginx;
in {
  config = lib.mkIf cfg.enable {
    networking.firewall.allowedUDPPorts = [53];
    services.adguardhome = {
      settings = {
        bind_port = adguardPort;
        bind_host = lib.mkIf (!cfg.openFirewall && nginx.enable) "127.0.0.1";
      };
    };

    services.nginx.virtualHosts.${config.networking.hostName}.locations = lib.mkIf nginx.enable {
      "/agh".return = "302 $scheme://$host/agh/";
      "/agh/" = {
        proxyPass = "http://127.0.0.1:${toString adguardPort}/";
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [adguardPort];
  };
}
