# ! This is the common wireguard configuration for all machines
# ! The definition of the server is a linux module in modules/linux/services/wireguard.nix
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfgWireguard = config.settings.wireguard;
  hosts = config.settings.hosts;
  host = hosts."${config.networking.hostName}";
  servers = lib.filterAttrs (_: cfg: cfg.wg.server.enable) hosts;
  clients = lib.filterAttrs (_: cfg: !cfg.wg.server.enable && host.id != cfg.id) hosts;
  wgIp = id: "${cfgWireguard.ipPrefix}.${builtins.toString id}";
in {
  options.settings = with lib; {
    wireguard = {
      server = {
        # * We don't move this to the toml config file as none of the other machines need to know such details
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
      address = ["${wgIp host.id}/24"];
      # Path to the private key file.
      privateKeyFile = config.age.secrets.wireguard.path;

      # ! Don't uncomment: it messes up /etc/resolv.conf on macos (replaces the other nameservers)
      # dns = lib.mapAttrsToList (_:cfg: "${wgIp cfg.id}") servers;

      autostart = true; # * Default is true, we keep it that way

      peers =
        lib.mkDefault
        (lib.mapAttrsToList (_: cfg: {
            publicKey = cfg.wg.publicKey;
            allowedIPs = ["${wgIp 0}/24"];
            endpoint = "${cfg.publicIP}:${builtins.toString cfg.wg.server.port}";
            # Send keepalives every 25 seconds. Important to keep NAT tables alive.
            persistentKeepalive = 25;
          })
          servers);
    };
  };
}
