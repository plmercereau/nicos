{
  config,
  lib,
  pkgs,
  cluster,
  ...
}: let
  domain = "local"; # TODO should be configurable. See Darwin config too.
  id = config.settings.id;
  vpn = config.settings.networking.vpn;
  bastion = vpn.bastion;
  inherit (cluster) hosts;
  servers = lib.filterAttrs (_: cfg: cfg.settings.networking.vpn.bastion.enable) hosts;
  clients = lib.filterAttrs (_: cfg: !cfg.settings.networking.vpn.bastion.enable && cfg.settings.id != id) hosts;
  inherit (config.lib.ext_lib) idToVpnIp;
in {
  config =
    lib.mkIf vpn.enable
    {
      services.dnsmasq = {
        enable = true;
        alwaysKeepRunning = true;
        resolveLocalQueries = true;
        settings = {
          inherit domain;
          local = "/${domain}/";
          # * Use DnsMasq to provide DNS service for the WireGuard clients.
          interface = ["lo"] ++ lib.optional bastion.enable vpn.interface;
          server = lib.mapAttrsToList (_:cfg: "${idToVpnIp}@${vpn.interface}") servers;
        };
      };

      # boot.kernel.sysctl."net.ipv4.ip_forward" = 1; #? unnecessary?

      networking = lib.mkIf bastion.enable {
        # nameservers = ["127.0.0.1" "::1"]; #? unnecessary?

        wg-quick.interfaces.${vpn.interface} = {
          # The port that WireGuard listens to. Must be accessible by the client.
          listenPort = bastion.port;
          peers = lib.mkForce (lib.mapAttrsToList (_: cfg: let
              id = cfg.settings.id;
              publicKey = cfg.settings.networking.vpn.publicKey;
            in {
              inherit publicKey;
              allowedIPs = ["${idToVpnIp}/32"];
            })
            clients);
        };
        # enable NAT
        nat = {
          inherit (bastion) externalInterface;
          enable = true;
          enableIPv6 = false;
          internalInterfaces = [vpn.interface];
        };

        # Open the DNS port on the Wireguard interface if this is a Wireguard server
        firewall = {
          # Open ports in the firewall
          allowedUDPPorts = [bastion.port];

          interfaces.${vpn.interface} = {
            allowedTCPPorts = [53];
            allowedUDPPorts = [53];
          };
        };

        # TODO public and local IPs too
        # TODO host.vpn -> Wireguard, host.lan -> local IP, host.public -> public IP, host -> Wireguard
        hosts = (
          lib.mapAttrs' (name: cfg: lib.nameValuePair idToVpnIp [name "${name}.wg" "${name}.${domain}"])
          hosts
        );
      };
    };
}
