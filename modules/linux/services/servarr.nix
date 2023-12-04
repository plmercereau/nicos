{
  config,
  modulesPath,
  pkgs,
  lib,
  ...
}: let
  radarr = config.services.radarr;
  prowlarr = config.services.prowlarr;
  nginx = config.services.nginx;
  # TODO sonarr
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
    "/prowlarr" = lib.mkIf (nginx.enable && prowlarr.enable) {
      proxyPass = "http://127.0.0.1:9696";
      recommendedProxySettings = true;
    };
    "/prowlarr(/[0-9]+)?/api" = lib.mkIf (nginx.enable && prowlarr.enable) {
      proxyPass = "http://127.0.0.1:9696";
    };
  };
}
