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
  isServer = host.wg.server.enable;
  isLinux = pkgs.hostPlatform.isLinux;
  ip = id: "${cfgWireguard.ipPrefix}.${builtins.toString id}";
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
    };
  };

  config = {
    # ???
    # boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

    networking =
      {
        wg-quick.interfaces = {
          # "wg0" is the network interface name. You can name the interface arbitrarily.
          wg0 = {
            # Determines the IP address and subnet of the server's end of the tunnel interface.
            address = ["${ip host.id}/24"];
            # Path to the private key file.
            privateKeyFile = config.age.secrets.wireguard.path;

            # The port that WireGuard listens to. Must be accessible by the client.
            listenPort = lib.mkIf isServer host.wg.server.port;

            # This allows the wireguard server to route your traffic to the internet and hence be like a VPN
            # For this to work you have to set the dnsserver IP of your router (or dnsserver of choice) in your clients
            # https://www.reddit.com/r/WireGuard/comments/ghp3ap/communicate_between_wireguard_peers/
            # postUp = lib.mkIf isServer ''
            #   ${pkgs.iptables}/bin/iptables -A FORWARD -i wg0 -j ACCEPT
            #   ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING
            #   ${pkgs.iptables}/bin/iptables -I FORWARD -i wg0 -o wg0 -j ACCEPT
            # '';

            # # This undoes the above command
            # preDown = lib.mkIf isServer ''
            #   ${pkgs.iptables}/bin/iptables -D FORWARD -i wg0 -j ACCEPT
            #   ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING
            #   ${pkgs.iptables}/bin/iptables -D FORWARD -i wg0 -o wg0 -j ACCEPT
            # '';

            peers =
              lib.attrValues
              (
                if isServer
                then
                  lib.mapAttrs (_:cfg: {
                    publicKey = cfg.wg.publicKey;
                    allowedIPs = ["${ip cfg.id}/32"];
                  })
                  clients
                else
                  lib.mapAttrs (_:cfg: {
                    publicKey = cfg.wg.publicKey;
                    allowedIPs = ["${ip 0}/24"];
                    endpoint = "${cfg.publicIP}:${builtins.toString cfg.wg.server.port}";
                    # Send keepalives every 25 seconds. Important to keep NAT tables alive.
                    persistentKeepalive = 25;
                  })
                  servers
              );
          };
        };
      }
      // lib.optionalAttrs isLinux {
        # enable NAT
        nat = lib.mkIf isServer {
          enable = true;
          enableIPv6 = false;
          externalInterface = cfgWireguard.server.externalInterface;
          internalInterfaces = ["wg0"];
        };
        # Open ports in the firewall
        firewall = lib.mkIf isServer {
          allowedUDPPorts = [host.wg.server.port];
        };
      };
  };
}
