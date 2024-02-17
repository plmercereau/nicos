{
  config,
  lib,
  pkgs,
  cluster,
  ...
}:
with lib; let
  vpn = config.settings.networking.vpn;
in {
  imports = [./bastion.nix ./client.nix];
  options.settings.networking.vpn = {
    enable = mkEnableOption "the Wireguard VPN";
    id = mkOption {
      description = ''
        Id of the machine. Each machine must have an unique value.

        This id will be translated into an IP with `settings.networking.vpn.bastion.cidr` when using the VPN module.
      '';
      type = types.nullOr types.int;
      default = null;
    };
    publicKey = mkOption {
      description = ''
        Wireguard public key of the machine.

        This value is required when the VPN is enabled.
      '';
      type = types.nullOr types.str;
      default = null;
    };
    # TODO cannot use another name than wg0?
    interface = mkOption {
      description = ''
        Name of the interface of the VPN interface.
      '';
      type = types.str;
      default = "wg0";
    };
    peers = mkOption {
      description = ''
        Set of publicKey = [allowedIPs] to add to the list of wireguard peers, in order to merge multiple definitions of the same public key.
      '';
      type = types.attrsOf (types.listOf types.str);
      default = {};
      internal = true;
    };
  };

  config = mkIf vpn.enable {
    assertions = [
      {
        assertion = !(vpn.enable && vpn.id == null);
        message = "The VPN is enabled but no machine ID is defined (settings.networking.vpn.id).";
      }
      {
        assertion = !(vpn.enable && vpn.publicKey == null);
        message = "The VPN is enabled but no Wireguard public key has been provided (settings.networking.vpn.publicKey).";
      }
    ];

    lib.vpn = let
      inherit (config.lib.network) ipv4;

      # Determines whether the current machine is a VPN server or not.
      # TODO replace by "config.lib.vpn.bastion" and "config.lib.vpn.clients"
      isServer = vpn.bastion.enable;
      bastion = findFirst (cfg: cfg.lib.vpn.isServer) (builtins.throw "bastion not found") (attrValues cluster.hosts);
      clients =
        filterAttrs
        (_: cfg: cfg.settings.networking.vpn.enable && !cfg.lib.vpn.isServer)
        cluster.hosts;

      inherit (bastion.settings.networking.vpn.bastion) cidr domain;

      /*
      Returns the VPN IP address given a CIDR and a machine id.
      It basically "adds" the machine ID to the network IP.
      */
      machineIp = cidr: id: let
        networkId = ipv4.cidrToNetworkId cidr;
        # TODO 192.168.0.255 -> 192.168.1.1 IF cidr allows it. Similarly, 192.168.0.256 -> 192.168.1.2
        listIp = ipv4.incrementIp networkId id;
      in
        ipv4.prettyIp listIp;

      # Returns the VPN IP address of the current machine.
      ip = machineIp cidr vpn.id;
      fqdn = "${config.networking.hostName}.${domain}";

      # Returns the VPN IP address of the current machine with the VPN network mask.
      ipWithMask = let
        bitMask = ipv4.cidrToBitMask cidr;
      in "${ip}/${toString bitMask}";
    in {
      inherit machineIp ip ipWithMask isServer bastion clients cidr domain fqdn;
    };

    # ! don't let the networkmanager manage the vpn interface for now as it conflicts with resolved
    networking.networkmanager.unmanaged = [vpn.interface];

    networking.wg-quick.interfaces.${vpn.interface} = {
      # Determines the IP address and subnet of the server's end of the tunnel interface.
      address = [config.lib.vpn.ipWithMask];

      # ! Don't use this setting as it replaces the entire DNS configuration of the machine once Wireguard is started
      # dns = [...];

      autostart = true; # * Default is true, we keep it that way

      peers =
        mkAfter
        (mapAttrsToList (publicKey: allowedIPs: {
            inherit publicKey allowedIPs;
          })
          vpn.peers);
    };
  };
}
