{
  config,
  lib,
  pkgs,
  cluster,
  ...
}:
with lib; let
  vpn = config.settings.networking.vpn;
  vpnLib = config.lib.vpn;
  servers = lib.filterAttrs (_: vpnLib.isServer) cluster.hosts;
  isServer = vpnLib.isServer config;
in {
  options.settings.networking.vpn = {
    enable = mkEnableOption "the Wireguard VPN";
    id = mkOption {
      description = ''
        Id of the machine. Each machine must have an unique value.

        This id will be translated into an IP with `settings.networking.vpn.cidr` when using the VPN module.
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
    interface = mkOption {
      description = ''
        Name of the interface of the VPN interface.
      '';
      type = types.str;
      default = "wg0";
    };
  };

  config = mkIf vpn.enable {
    assertions = [
      (let
        ids = mapAttrsToList (_: v: v.settings.networking.vpn.id) cluster.hosts;
        duplicates = sort (p: q: p < q) (unique (filter (id: ((count (v: v == id) ids) > 1)) ids));
      in {
        assertion = (length duplicates) == 0;
        message = "Duplicate VPN machine IDs: ${toString (map toString duplicates)}.";
      })
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
      /*
      Returns the VPN IP address given a machine id.
      The IP is calculated from the network CIDR and the machine ID.
      It basically "adds" the machine ID to the network IP.
      */
      machineIp = cfg: let
        inherit (cfg.settings.networking.vpn) cidr id;
        networkId = ipv4.cidrToNetworkId cidr;
        listIp = ipv4.incrementIp networkId id;
      in
        ipv4.prettyIp listIp;

      # Returns the VPN IP address of the current machine.
      ip = machineIp config;

      # Returns the VPN IP address of the current machine with the VPN network mask.
      ipWithMask = let
        bitMask = ipv4.cidrToBitMask vpn.cidr;
      in "${ip}/${toString bitMask}";

      # Determines whether the current machine is a VPN server or not. Note the bastion attribute doesn't exist on Darwin.
      isServer = cfg: cfg.settings.networking.vpn ? "bastion" && cfg.settings.networking.vpn.bastion.enable;
    in {
      inherit machineIp ip ipWithMask isServer;
    };

    networking.wg-quick.interfaces.${vpn.interface} = {
      # Determines the IP address and subnet of the server's end of the tunnel interface.
      address = [vpnLib.ipWithMask];
      # Path to the private key file.
      privateKeyFile = config.age.secrets.vpn.path;

      # ! Don't use this setting as it replaces the entire DNS configuration of the machine once Wireguard is started
      # dns = [...];

      autostart = true; # * Default is true, we keep it that way

      peers =
        mkDefault
        (mapAttrsToList (_: cfg: let
            netSettings = cfg.settings.networking;
          in {
            inherit (netSettings.vpn) publicKey;
            allowedIPs = [vpn.cidr];
            endpoint = "${netSettings.publicIP}:${builtins.toString netSettings.vpn.bastion.port}";
            # Send keepalives every 25 seconds. Important to keep NAT tables alive.
            persistentKeepalive = 25;
          })
          servers);
    };
  };
}
