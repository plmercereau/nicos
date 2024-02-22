{
  config,
  lib,
  pkgs,
  cluster,
  ...
}:
with lib; let
  inherit (config.settings) vpn;
in {
  imports = [./bastion.nix ./client.nix];
  options.settings.vpn = {
    enable = mkEnableOption "the Wireguard VPN";
    id = mkOption {
      description = ''
        Id of the machine. Each machine must have an unique value.

        This id will be translated into an IP with `settings.vpn.bastion.cidr` when using the VPN module.
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
        message = "The VPN is enabled but no machine ID is defined (settings.vpn.id).";
      }
      {
        assertion = !(vpn.enable && vpn.publicKey == null);
        message = "The VPN is enabled but no Wireguard public key has been provided (settings.vpn.publicKey).";
      }
    ];

    lib.vpn = let
      inherit (config.lib.network) ipv4;
      hosts =
        filterAttrs
        (_: cfg: cfg.settings.vpn.enable)
        cluster.hosts;
      bastions = filterAttrs (_: cfg: cfg.settings.vpn.bastion.enable) hosts;
      bastion = head (attrValues bastions);
      inherit (bastion.settings.vpn.bastion) cidr domain;
    in rec {
      inherit hosts bastions bastion;
      clients =
        filterAttrs
        (name: _: ! (elem name (attrNames bastions)))
        hosts;

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
      ipWithMask = "${ip}/${toString (ipv4.cidrToBitMask cidr)}";
    };

    # ! don't let the networkmanager manage the vpn interface for now as it conflicts with resolved
    networking.networkmanager.unmanaged = ["wg0"];

    networking.wg-quick.interfaces.wg0 = {
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
