{
  config,
  lib,
  pkgs,
  ...
}: let
  cfgWireguard = config.settings.wireguard;
  cluster = config.settings.cluster;
  id = config.settings.id;
  clients = lib.filterAttrs (_: cfg: !cfg.settings.wireguard.server.enable && cfg.settings.id != id) cluster;
  wgIp = id: "${cfgWireguard.ipPrefix}.${builtins.toString id}";
in {
  config =
    lib.mkIf cfgWireguard.server.enable
    {
      # boot.kernel.sysctl."net.ipv4.ip_forward" = 1; #? unnecessary?
      # * Use DnsMasq to provide DNS service for the WireGuard clients.
      services.dnsmasq.settings.interface = [cfgWireguard.interface];

      networking = {
        # nameservers = ["127.0.0.1" "::1"]; #? unnecessary?

        wg-quick.interfaces."${cfgWireguard.interface}" = {
          # The port that WireGuard listens to. Must be accessible by the client.
          listenPort = cfgWireguard.server.port;
          peers = lib.mkForce (lib.mapAttrsToList (_: cfg: let
              inherit (cfg.settings) id wireguard;
            in {
              inherit (wireguard) publicKey;
              allowedIPs = ["${wgIp id}/32"];
            })
            clients);
        };
        # enable NAT
        nat = {
          enable = true;
          enableIPv6 = false;
          externalInterface = cfgWireguard.server.externalInterface;
          internalInterfaces = [cfgWireguard.interface];
        };
        # Open ports in the firewall
        firewall.allowedUDPPorts = [cfgWireguard.server.port];

        hosts = (
          lib.mapAttrs' (name: cfg: lib.nameValuePair (wgIp cfg.settings.id) [name "${name}.wg" "${name}.local"])
          cluster
        );
      };
    };
}
