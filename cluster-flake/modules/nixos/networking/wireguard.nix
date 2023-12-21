{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (config.settings) wireguard id;
  hosts = config.cluster.hosts.config;
  clients = lib.filterAttrs (_: cfg: !cfg.settings.wireguard.server.enable && cfg.settings.id != id) hosts;
  wgIp = id: "${wireguard.ipPrefix}.${builtins.toString id}";
in {
  config =
    lib.mkIf wireguard.server.enable
    {
      # boot.kernel.sysctl."net.ipv4.ip_forward" = 1; #? unnecessary?
      # * Use DnsMasq to provide DNS service for the WireGuard clients.
      services.dnsmasq.settings.interface = [wireguard.interface];

      networking = {
        # nameservers = ["127.0.0.1" "::1"]; #? unnecessary?

        wg-quick.interfaces.${wireguard.interface} = {
          # The port that WireGuard listens to. Must be accessible by the client.
          listenPort = wireguard.server.port;
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
          externalInterface = wireguard.server.externalInterface;
          internalInterfaces = [wireguard.interface];
        };
        # Open ports in the firewall
        firewall.allowedUDPPorts = [wireguard.server.port];

        hosts = (
          lib.mapAttrs' (name: cfg: lib.nameValuePair (wgIp cfg.settings.id) [name "${name}.wg" "${name}.local"])
          hosts
        );
      };
    };
}
