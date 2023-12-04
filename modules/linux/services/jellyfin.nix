{
  config,
  modulesPath,
  pkgs,
  lib,
  ...
}: let
  cfg = config.services.jellyfin;
  nginx = config.services.nginx;
  jellyfinPort = 8096;
in {
  config = lib.mkIf cfg.enable {
    users.users.jellyfin.extraGroups = lib.mkIf config.services.transmission.enable [config.services.transmission.user];

    # * See: https://unix.stackexchange.com/questions/64812/get-transmission-web-interface-working-with-web-server
    services.nginx.virtualHosts.${config.networking.hostName}.locations = lib.mkIf nginx.enable {
      # * See: https://jellyfin.org/docs/general/networking/nginx/
      "/jellyfin".return = "302 $scheme://$host/jellyfin/";
      "/jellyfin/".proxyPass = "http://127.0.0.1:${toString jellyfinPort}/jellyfin/";
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [jellyfinPort];
    systemd.services.jellyfin.serviceConfig.UMask = lib.mkForce "0007"; # create files with 770 permissions
  };
}
