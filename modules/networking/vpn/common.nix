# ! This is the common vpn/Wireguard/dnsmasq configuration for all machines
# ! The definition of the server is a nixos module in ./nixos.nix
{
  config,
  lib,
  pkgs,
  cluster,
  ...
}: let
  vpn = config.settings.networking.vpn;
  id = config.settings.id;
  inherit (cluster) hosts;
  servers = lib.filterAttrs (_: cfg: cfg.settings.networking.vpn.bastion.enable) hosts;
  inherit (config.lib.ext_lib) idToVpnIpWithMask;
in {
  options.settings.networking.vpn = with lib; {
    enable = mkEnableOption "the Wireguard VPN";
    publicKey = mkOption {
      description = ''
        Wireguard public key of the machine.

        This value is required when the VPN is enabled.
      '';
      type = types.str;
      # TODO wireguard public key validation
      default =
        # Workaround for making sure the option is set when the VPN is enabled
        if vpn.enable
        then null
        else "";
    };
    bastion = {
      enable = mkEnableOption "the machine as a VPN server";
      port = mkOption {
        description = ''
          Port of the VPN server.

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
    cidr = mkOption {
      description = ''
        CIDR of the VPN.

        In addition to determining the VPN network, it also determines the machine IP address from the machine ID on the VPN.

        For instance, if the CIDR is `10.100.0.0/24` and `settings.id` is `5`, then the machine IP address will be `10.100.0.5`.
      '';
      type = types.str;
      default = "10.100.0.0/24";
    };
    interface = mkOption {
      description = ''
        Name of the interface of the VPN interface.
      '';
      type = types.str;
      default = "wg0";
    };
  };

  config = lib.mkIf vpn.enable {
    # ???
    # boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
    networking.wg-quick.interfaces.${vpn.interface} = {
      # Determines the IP address and subnet of the server's end of the tunnel interface.
      address = [idToVpnIpWithMask];
      # Path to the private key file.
      privateKeyFile = config.age.secrets.vpn.path;

      # ! Don't uncomment: it messes up /etc/resolv.conf on macos (replaces the other nameservers)
      # TODO solve this up, as it would avoid using dnsmasq for clients, but only on bastions
      # dns = lib.mapAttrsToList (_:cfg: "${idToVpnIp}") servers;

      autostart = true; # * Default is true, we keep it that way

      peers =
        lib.mkDefault
        (lib.mapAttrsToList (_: cfg: let
            inherit (cfg.settings.networking) publicIP vpn;
          in {
            inherit (vpn) publicKey;
            allowedIPs = [vpn.cidr];
            endpoint = "${publicIP}:${builtins.toString vpn.bastion.port}";
            # Send keepalives every 25 seconds. Important to keep NAT tables alive.
            persistentKeepalive = 25;
          })
          servers);
    };
  };
}
