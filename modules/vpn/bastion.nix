{
  config,
  options,
  lib,
  pkgs,
  cluster,
  ...
}:
with lib; let
  vpn = config.settings.vpn;
  cfg = vpn.bastion;
  inherit (config.lib.vpn) machineIp clients hosts;
in {
  options.settings.vpn.bastion = {
    enable = mkOption {
      # TODO check if there is only one bastion
      description = ''
        Whether to enable the Wireguard VPN server on this machine.
      '';
      type = types.bool;
      default = false;
    };
    port = mkOption {
      # TODO kube-vip is using 51820 so we CANNOT change this port without a PR in kube-vip
      description = ''

        This port must not be block by an external firewall so clients can reach it.
      '';
      type = types.int;
      default = 51820;
    };
    cidr = mkOption {
      description = ''
        CIDR that defines the VPN network.

        It is also required to determine the machine IP address from the machine ID on the VPN.

        For instance, if the CIDR is `10.100.0.0/24` and `settings.vpn.id` is `5`, then the machine IP address will be `10.100.0.5`.
      '';
      type = types.str;
      default = "10.100.0.0/24";
    };
    domain = mkOption {
      description = ''
        Domain name of the VPN.

        The machines will then be accessible through `hostname.domain`.
      '';
      type = types.str;
      default = "vpn";
    };
    externalInterface = mkOption {
      description = ''
        External interface of the bastion for NAT.
      '';
      type = types.str;
      default = "eth0";
    };
    extraPeers = mkOption {
      description = ''
        Extra machines to add to the VPN.

        This is useful when you want to add a machine to the VPN that is not part of the cluster.
      '';
      type = types.attrsOf (types.submodule {
        options = {
          inherit (options.settings.vpn) id publicKey;
        };
      });
      default = {};
    };
  };

  config =
    mkIf (vpn.enable && cfg.enable)
    {
      assertions = [
        (let
          ids =
            (mapAttrsToList (_: v: v.settings.vpn.id) cluster.hosts)
            ++ (mapAttrsToList (_: machine: machine.id) cfg.extraPeers);
          duplicates = sort (p: q: p < q) (unique (filter (id: ((count (v: v == id) ids) > 1)) ids));
        in {
          assertion = (length duplicates) == 0;
          message = "Duplicate VPN machine IDs: ${toString (map toString duplicates)}.";
        })
        {
          assertion = (length (attrNames config.lib.vpn.bastions)) < 2;
          message = "Multiple VPN bastions are not supported yet.";
        }
      ];

      services.dnsmasq = {
        enable = true;
        alwaysKeepRunning = true;
        # Use DnsMasq to provide DNS service for the WireGuard clients.
        settings.interface = [vpn.interface];
        # * We add the list of the enabled hosts with their VPN IP and name.vpn-domain so dnsmasq can resolve them as well as their subdomains.
        settings.address =
          lib.mapAttrsToList (name: machine: "/${name}.${cfg.domain}/${machineIp cfg.cidr machine.settings.vpn.id}")
          hosts;
      };

      # TODO understand what in the configuration enables systemd. Could it be cloud-init?
      services.resolved.enable = mkForce false;
      systemd.services.systemd-resolved.enable = mkForce false;

      settings.vpn.peers = mapAttrs' (_: machine: nameValuePair (machine.publicKey) ["${machineIp cfg.cidr machine.id}/32"]) (
        # Add the list of the client machines configured in the cluster of machines
        (
          mapAttrs (_: cfg: {inherit (cfg.settings.vpn) publicKey id;}) clients
        )
        # Also add extra Peers that are not part of the cluster
        // cfg.extraPeers
      );

      networking = {
        wg-quick.interfaces.${vpn.interface} = {
          listenPort = cfg.port;
        };

        # enable NAT
        nat = {
          inherit (cfg) externalInterface;
          enable = true;
          enableIPv6 = false;
          internalInterfaces = [vpn.interface];
        };

        # Open the DNS port on the Wireguard interface if this is a Wireguard server
        firewall = {
          # Open ports in the firewall
          allowedUDPPorts = [cfg.port];

          interfaces.${vpn.interface} = {
            allowedTCPPorts = [53];
            allowedUDPPorts = [53];
          };
        };
      };
    };
}
