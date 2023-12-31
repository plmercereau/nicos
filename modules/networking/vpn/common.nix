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
  inherit (config.lib.ext_lib) idToVpnIp;
in {
  options.settings.networking.vpn = with lib; {
    enable = mkEnableOption "the Wireguard VPN";
    publicKey = mkOption {
      description = "public key of the vpn (Wireguard) interface";
      type = types.str;
      default = "";
    };
    bastion = {
      enable = mkEnableOption "the machine as a VPN server";
      port = mkOption {
        description = "port of ssh bastion server";
        type = types.int;
        default = 51820;
      };
      externalInterface = mkOption {
        description = "external interface of the bastion";
        type = types.str;
        default = "eth0";
      };
    };
    ipPrefix = mkOption {
      description = "IP prefix of the machine";
      type = types.str;
      default = "10.100.0";
    };
    ip = mkOption {
      description = ''
        VPN IP address of the machine.

        Defaults to `"''${config.settings.vpn.ipPrefix}.''${config.settings.id}"`.
      '';
      type = types.str;
      default = idToVpnIp config.settings.id;
    };
    interface = mkOption {
      description = "interface name of the vpn (Wireguard) interface";
      type = types.str;
      default = "wg0";
    };
  };

  config = lib.mkIf vpn.enable {
    # ???
    # boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
    networking.wg-quick.interfaces.${vpn.interface} = {
      # Determines the IP address and subnet of the server's end of the tunnel interface.
      address = ["${idToVpnIp id}/24"];
      # Path to the private key file.
      privateKeyFile = config.age.secrets.vpn.path;

      # ! Don't uncomment: it messes up /etc/resolv.conf on macos (replaces the other nameservers)
      # dns = lib.mapAttrsToList (_:cfg: "${idToVpnIp cfg.id}") servers;

      autostart = true; # * Default is true, we keep it that way

      peers =
        lib.mkDefault
        (lib.mapAttrsToList (_: cfg: let
            inherit (cfg.settings.networking) publicIP vpn;
          in {
            inherit (vpn) publicKey;
            allowedIPs = ["${idToVpnIp 0}/24"];
            endpoint = "${publicIP}:${builtins.toString vpn.bastion.port}";
            # Send keepalives every 25 seconds. Important to keep NAT tables alive.
            persistentKeepalive = 25;
          })
          servers);
    };
  };
}
