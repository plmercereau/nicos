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
  inherit (config.lib.ext_lib) wgIp;
in {
  options.settings.networking.vpn = with lib; {
    enable = mkEnableOption "Is the machine using a vpn (Wireguard)";
    publicKey = mkOption {
      description = "public key of the vpn (Wireguard) interface";
      type = types.str;
      default = "";
    };
    bastion = {
      enable = mkEnableOption "Is the machine a WireGuard bastion";
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
      description = "(INTERNAL) calculated IP of the machine";
      type = types.str;
      internal = true;
    };
    interface = mkOption {
      description = "interface name of the vpn (Wireguard) interface";
      type = types.str;
      default = "wg0";
    };
  };

  config = lib.mkIf vpn.enable {
    settings.networking.vpn.ip = wgIp id;
    # ???
    # boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
    networking.wg-quick.interfaces.${vpn.interface} = {
      # Determines the IP address and subnet of the server's end of the tunnel interface.
      address = ["${wgIp id}/24"];
      # Path to the private key file.
      privateKeyFile = config.age.secrets.vpn.path;

      # ! Don't uncomment: it messes up /etc/resolv.conf on macos (replaces the other nameservers)
      # dns = lib.mapAttrsToList (_:cfg: "${wgIp cfg.id}") servers;

      autostart = true; # * Default is true, we keep it that way

      peers =
        lib.mkDefault
        (lib.mapAttrsToList (_: cfg: let
            inherit (cfg.settings.networking) publicIP vpn;
          in {
            inherit (vpn) publicKey;
            allowedIPs = ["${wgIp 0}/24"];
            endpoint = "${publicIP}:${builtins.toString vpn.bastion.port}";
            # Send keepalives every 25 seconds. Important to keep NAT tables alive.
            persistentKeepalive = 25;
          })
          servers);
    };
  };
}
