{
  config,
  lib,
  pkgs,
  cluster,
  ...
}:
with lib; let
  id = config.settings.id;
  vpn = config.settings.networking.vpn;
  inherit (cluster) hosts;
  clients = filterAttrs (_: cfg: !(config.lib.vpn.isServer cfg) && cfg.settings.id != id) hosts;
  inherit (config.lib.vpn) ip machineIp;
in {
  options.settings.networking.vpn.bastion = {
    enable = mkOption {
      description = ''
        Whether to enable the Wireguard VPN server on this machine.
      '';
      type = types.bool;
      default = false;
    };
    port = mkOption {
      description = ''

        This port must not be block by an external firewall so clients can reach it.
      '';
      type = types.int;
      default = 51820;
    };
    externalInterface = mkOption {
      description = ''
        External interface of the bastion for NAT.
      '';
      type = types.str;
      default = "eth0";
    };
  };

  config =
    mkIf (vpn.enable && vpn.bastion.enable)
    {
      services.dnsmasq = {
        enable = true;
        alwaysKeepRunning = true;
        # Use DnsMasq to provide DNS service for the WireGuard clients.
        settings.interface = [vpn.interface];
      };

      # TODO understand what in the configuration enables systemd. Could it be cloud-init?
      services.resolved.enable = mkForce false;
      systemd.services.systemd-resolved.enable = mkForce false;

      networking = {
        wg-quick.interfaces.${vpn.interface} = {
          listenPort = vpn.bastion.port;
          # On servers, override the default peer list with a strict allowed IP and no endpoint and do not include servers.
          peers = mkForce (mapAttrsToList (_: cfg: {
              inherit (cfg.settings.networking.vpn) publicKey;
              allowedIPs = ["${machineIp cfg}/32"]; # ? Is /32 necessary?
            })
            clients);
        };

        # enable NAT
        nat = {
          inherit (vpn.bastion) externalInterface;
          enable = true;
          enableIPv6 = false;
          internalInterfaces = [vpn.interface];
        };

        # Open the DNS port on the Wireguard interface if this is a Wireguard server
        firewall = {
          # Open ports in the firewall
          allowedUDPPorts = [vpn.bastion.port];

          interfaces.${vpn.interface} = {
            allowedTCPPorts = [53];
            allowedUDPPorts = [53];
          };
        };

        # * We add the list of the hosts with their VPN IP and name + name.vpn-domain to /etc/hosts so dnsmasq can resolve them.
        hosts = (
          lib.mapAttrs' (name: cfg: lib.nameValuePair (machineIp cfg) [name "${name}.${vpn.domain}"])
          hosts
        );
      };
    };
}
