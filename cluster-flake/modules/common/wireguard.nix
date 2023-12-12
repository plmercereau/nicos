# ! This is the common wireguard configuration for all machines
# ! The definition of the server is a nixos module in modules/nixos/services/wireguard.nix
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfgWireguard = config.settings.wireguard;
  id = config.settings.id;
  servers = lib.filterAttrs (_: cfg: cfg.settings.wireguard.server.enable) config.cluster.hosts.config;
  wgIp = id: "${cfgWireguard.ipPrefix}.${builtins.toString id}";
in {
  options.settings = with lib; {
    wireguard = {
      publicKey = mkOption {
        description = "public key of the wireguard interface";
        type = types.str;
        default = "";
      };
      server = {
        enable = mkEnableOption {
          description = "Is the machine a WireGuard bastion";
        };
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
      interface = mkOption {
        description = "interface name of the wireguard interface";
        type = types.str;
        default = "wg0";
      };
    };
  };

  config = {
    # ???
    # boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

    networking.wg-quick.interfaces."${cfgWireguard.interface}" = {
      # Determines the IP address and subnet of the server's end of the tunnel interface.
      address = ["${wgIp id}/24"];
      # Path to the private key file.
      privateKeyFile = config.age.secrets.wireguard.path;

      # ! Don't uncomment: it messes up /etc/resolv.conf on macos (replaces the other nameservers)
      # dns = lib.mapAttrsToList (_:cfg: "${wgIp cfg.id}") servers;

      autostart = true; # * Default is true, we keep it that way

      peers =
        lib.mkDefault
        (lib.mapAttrsToList (_: cfg: let
            inherit (cfg.settings) publicIP wireguard;
          in {
            inherit (wireguard) publicKey;
            allowedIPs = ["${wgIp 0}/24"];
            endpoint = "${publicIP}:${builtins.toString wireguard.server.port}";
            # Send keepalives every 25 seconds. Important to keep NAT tables alive.
            persistentKeepalive = 25;
          })
          servers);
    };
  };
}
