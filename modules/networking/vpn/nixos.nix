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
  bastion = vpn.bastion;
  isServer = vpn.bastion.enable;
  inherit (cluster) hosts;
  servers = filterAttrs (_: config.lib.vpn.isServer) hosts;
  clients = filterAttrs (_: cfg: !(config.lib.vpn.isServer cfg) && cfg.settings.id != id) hosts;
  inherit (config.lib.vpn) ip machineIp;
in {
  options.settings.networking.vpn = {
    bastion = {
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
  };
  config =
    mkIf vpn.enable
    {
      services.dnsmasq = mkIf isServer {
        enable = true;
        alwaysKeepRunning = true;
        settings = {
          listen-address = ["0.0.0.0"]; # TODO remove, or be more restrictive e.g. use the CIDR of the VPN
          # * Use DnsMasq to provide DNS service for the WireGuard clients.
          interface = [vpn.interface];
        };
      };

      # boot.kernel.sysctl."net.ipv4.ip_forward" = 1; #? unnecessary?

      # TODO understand what in the configuration enables systemd. Could it be cloud-init?
      services.resolved.enable = mkIf isServer (mkForce false);
      systemd.services.systemd-resolved.enable = mkIf isServer (mkForce false);

      networking = {
        wg-quick.interfaces.${vpn.interface} =
          if isServer
          then {
            listenPort = bastion.port;
            # On servers, override the default peer list with a strict allowed IP and no endpoint.
            peers = mkForce (mapAttrsToList (_: cfg: {
                inherit (cfg.settings.networking.vpn) publicKey;
                allowedIPs = ["${machineIp cfg}/32"]; # ? Is /32 necessary?
              })
              clients);
          }
          else {
            # Add an entry to systemd-resolved for each VPN server
            postUp = ''
              ${concatStringsSep "\n" (mapAttrsToList (_: cfg: ''
                  resolvectl dns ${cfg.settings.networking.vpn.interface} ${machineIp cfg}:53
                  resolvectl domain ${cfg.settings.networking.vpn.interface} ${vpn.domain}
                '')
                servers)}
            '';

            # When the VPN is down, remove the entries from systemd-resolved
            postDown = ''
              ${concatStringsSep "\n" (mapAttrsToList (_: cfg: ''
                  resolvectl dns ${cfg.settings.networking.vpn.interface}
                '')
                servers)}

            '';
          };

        # enable NAT
        nat = mkIf isServer {
          inherit (bastion) externalInterface;
          enable = true;
          enableIPv6 = false;
          internalInterfaces = [vpn.interface];
        };

        # Open the DNS port on the Wireguard interface if this is a Wireguard server
        firewall = mkIf isServer {
          # Open ports in the firewall
          allowedUDPPorts = [bastion.port];

          interfaces.${vpn.interface} = {
            allowedTCPPorts = [53];
            allowedUDPPorts = [53];
          };
        };

        # * We add the list of the hosts with their VPN IP and name + name.vpn-domain to /etc/hosts so dnsmasq can resolve them.
        hosts = mkIf isServer (
          lib.mapAttrs' (name: cfg: lib.nameValuePair (machineIp cfg) [name "${name}.${vpn.domain}"])
          hosts
        );
      };
    };
}
