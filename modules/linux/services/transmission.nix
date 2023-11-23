{
  config,
  modulesPath,
  pkgs,
  lib,
  ...
}: let
  cfg = config.services.transmission;
  nginx = config.services.nginx;
in {
  config = lib.mkIf cfg.enable {
    # TODO move to a new "transmission" module
    # TODO download directory, etc.
    # TODO magnet links https://forum.transmissionbt.com/viewtopic.php?t=18335
    services.transmission = {
      #   openRPCPort = true; #Open firewall for RPC
      # * https://github.com/transmission/transmission/blob/main/docs/Editing-Configuration-Files.md
      settings = {
        rpc-whitelist-enabled = true;
        # TODO
        # rpc-whitelist = "127.0.0.1,10.136.1.*"; #Whitelist your remote machine (10.0.0.1 in this example)
        rpc-whitelist = "*";
        rpc-host-whitelist-enabled = true;
        rpc-host-whitelist = "127.0.0.1,${config.networking.hostName}";
        speed-limit-up-enabled = true;
        speed-limit-up = 1; #KB/s
      };
    };

    # * See: https://unix.stackexchange.com/questions/64812/get-transmission-web-interface-working-with-web-server
    services.nginx.virtualHosts.${config.networking.hostName}.locations = lib.mkIf nginx.enable {
      "/transmission" = {
        proxyPass = "http://127.0.0.1:${toString cfg.settings.rpc-port}";
        extraConfig = ''
          proxy_pass_header  X-Transmission-Session-Id;
          proxy_set_header   X-Forwarded-Host $host;
          proxy_set_header   X-Forwarded-Server $host;
          proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        '';
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openRPCPort [cfg.settings.rpc-port];
  };
}
