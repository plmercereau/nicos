{
  config,
  lib,
  pkgs,
  ...
}: let
  cfgWireguard = config.settings.wireguard;
  hosts = config.settings.hosts;
  host = hosts."${config.networking.hostName}";
  clients = lib.filterAttrs (_: cfg: !cfg.wg.server.enable && host.id != cfg.id) hosts;
  wgIp = id: "${cfgWireguard.ipPrefix}.${builtins.toString id}";
in {
  config =
    lib.mkIf host.wg.server.enable
    {
      # boot.kernel.sysctl."net.ipv4.ip_forward" = 1; #? unnecessary?
      # * Use DnsMasq to provide DNS service for the WireGuard clients.
      services.dnsmasq.settings.interface = [cfgWireguard.interface];

      networking = {
        # nameservers = ["127.0.0.1" "::1"]; #? unnecessary?

        wg-quick.interfaces."${cfgWireguard.interface}" = {
          # The port that WireGuard listens to. Must be accessible by the client.
          listenPort = host.wg.server.port;
          peers = lib.mkForce (lib.mapAttrsToList (_: cfg: {
              publicKey = cfg.wg.publicKey;
              allowedIPs = ["${wgIp cfg.id}/32"];
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
        firewall.allowedUDPPorts = [host.wg.server.port];

        hosts = (
          lib.mapAttrs' (name: cfg: lib.nameValuePair (wgIp cfg.id) [name "${name}.wg" "${name}.local"])
          hosts
        );
      };
    };
}
