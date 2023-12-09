{
  config,
  modulesPath,
  pkgs,
  lib,
  ...
}: let
  radarr = config.services.radarr;
  prowlarr = config.services.prowlarr;
  sonarr = config.services.sonarr;
  bazarr = config.services.bazarr;
  nginx = config.services.nginx;
in {
  /*
  TODO declarative configuration for radarr and prowlarr, in particular:
  - change "baseURL" in both apps to "/radarr" and "/prowlarr" respectively
  - configure clients e.g. aria2, transmission, etc.
  - connnect radarr/sonarr with prowlarr
  - configure indexers
  - directories
  - secrets
  */
  services.nginx.virtualHosts.${config.networking.hostName}.locations = {
    "/radarr" = lib.mkIf (nginx.enable && radarr.enable) {
      proxyPass = "http://127.0.0.1:7878";
      recommendedProxySettings = true;
    };
    "/radarr(/[0-9]+)?/api" = lib.mkIf (nginx.enable && radarr.enable) {
      proxyPass = "http://127.0.0.1:7878";
    };
    "/sonarr" = lib.mkIf (nginx.enable && sonarr.enable) {
      proxyPass = "http://127.0.0.1:8989";
      recommendedProxySettings = true;
    };
    "/sonarr(/[0-9]+)?/api" = lib.mkIf (nginx.enable && sonarr.enable) {
      proxyPass = "http://127.0.0.1:8989";
    };
    "/prowlarr" = lib.mkIf (nginx.enable && prowlarr.enable) {
      proxyPass = "http://127.0.0.1:9696";
      recommendedProxySettings = true;
    };
    "/prowlarr(/[0-9]+)?/api" = lib.mkIf (nginx.enable && prowlarr.enable) {
      proxyPass = "http://127.0.0.1:9696";
    };
    "/bazarr" = lib.mkIf (nginx.enable && bazarr.enable) {
      proxyPass = "http://127.0.0.1:6767";
      recommendedProxySettings = true;
    };
    "/bazarr(/[0-9]+)?/api" = lib.mkIf (nginx.enable && bazarr.enable) {
      proxyPass = "http://127.0.0.1:6767";
    };
  };
  systemd.services.radarr.serviceConfig.UMask = lib.mkIf radarr.enable "0007"; # create files with 770 permissions
  systemd.services.sonarr.serviceConfig.UMask = lib.mkIf sonarr.enable "0007"; # create files with 770 permissions
  systemd.services.bazarr.serviceConfig.UMask = lib.mkIf bazarr.enable "0007"; # create files with 770 permissions
}
