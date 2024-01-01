{
  config,
  modulesPath,
  pkgs,
  lib,
  cluster,
  ...
}: let
  cfg = config.services.blocky;
  inherit (cluster) hosts;
  withLocalIP = lib.filterAttrs (_:cfg: cfg.settings.networking.localIP != null) hosts;
in {
  config = lib.mkIf cfg.enable {
    networking.firewall.allowedUDPPorts = [53];
    services.blocky = {
      settings = {
        # * Filter out IPv6 queries - ipv6 is not working somewhere and as a result the blacklist cannot be updated
        filtering.queryTypes = ["AAAA"];

        ports = {
          dns = 53;
          # http= 4000;
          # https= 443;
        };
        upstreams = {
          strategy = "parallel_best"; # or "strict"
          groups = {
            default = [
              # "195.130.131.1" # Telenet DNS
              # "195.130.130.1" # Telenet DNS
              "1.1.1.1"
              "8.8.8.8"
            ];
          };
        };
        customDNS = {
          customTTL = "1h";
          filterUnmappedTypes = true;
          rewrite = {
            # home = "lan";
            # "replace-me.com" = "with-this.com";
          };

          # * Create <hostname>.<local-domain> = <ip> entries for all hosts when they have a local IP
          mapping =
            # TODO map public IPs too
            lib.mapAttrs'
            (name: cfg: lib.nameValuePair "${name}.${cfg.settings.networking.localDomain}" cfg.settings.networking.localIP)
            withLocalIP;
        };
        clientLookup = {
          singleNameOrder = [2 1];
          clients =
            lib.mapAttrs
            (_: cfg: [cfg.settings.networking.localIP])
            withLocalIP;
        };
        blocking = {
          blackLists = {
            ads = [
              # * See: https://github.com/nextdns/blocklists/tree/main/blocklists
              "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling-porn/hosts" # Steven's extended blacklist
              "https://big.oisd.nl/regex" # ads, spyware, etc
            ];
            adult = [
              "https://nsfw.oisd.nl/regex" # adult content / not safe for work
            ];
          };
          whiteLists = {
            # ads = [
            # "www.1337xxx.to"
            # ! remove - useless
            # ''
            #   # inline workaround for regexes
            #   /github.com$/
            #   /githubusercontent.com$/
            # ''
            # ];
          };
          clientGroupsBlock = {
            default = ["adult"];
          };
        };
        # ? redis ? not useful for home use i.e. only one instance
        # log.level = "debug";
      };
    };
  };
}
