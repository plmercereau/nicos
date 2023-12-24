{
  config,
  modulesPath,
  pkgs,
  lib,
  ...
}: let
  cfg = config.services.nginx;
  radarr = config.services.radarr;
  prowlarr = config.services.prowlarr;
  sonarr = config.services.sonarr;
  bazarr = config.services.bazarr;
  jellyfin = config.services.jellyfin;
  transmission = config.services.transmission;

  # TODO use symlinkJoin or something similar in addition to writeTextDir in order to attach css
  # See: https://github.com/NixOS/nixpkgs/blob/b856b24bfaf44dd7c101d1afbefec850e968365a/pkgs/build-support/trivial-builders.nix
  index = pkgs.writeTextDir "index.html" ''
    <html>
        <head>
            <title>Fennec</title>
        </head>
    <body>
        <h1>Welcome</h1>
        <ul>
            ${lib.optionalString jellyfin.enable ''<li><a href="/jellyfin/web/index.html">Jellyfin</a></li>''}
            ${lib.optionalString radarr.enable ''<li><a href="/radarr">Radarr</a></li>''}
            ${lib.optionalString sonarr.enable ''<li><a href="/sonarr">Sonarr</a></li>''}
            ${lib.optionalString bazarr.enable ''<li><a href="/bazarr/series">Bazarr</a></li>''}
            ${lib.optionalString prowlarr.enable ''<li><a href="/prowlarr">Prowlarr</a></li>''}
            ${lib.optionalString transmission.enable ''<li><a href="/transmission/web/">Transmission</a></li>''}
        </ul>
      </body>
    </html>
  '';
in {
  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [80 443];

    services.nginx = {
      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;
      recommendedProxySettings = true;

      virtualHosts.${config.networking.hostName}.locations = lib.mkIf cfg.enable {
        "/" = {
          root = index.outPath;
          index = "index.html";
        };
      };
    };
  };
}
