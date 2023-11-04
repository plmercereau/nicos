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
  # ? add a check: darwin machines can't be servers
  hostOpts = {
    name,
    config,
    ...
  }: {
    options = with lib; {
      id = mkOption {
        description = "Id of the machine, that will be translated into an IP";
        type = types.int;
      };
      sshPublicKey = mkOption {
        description = "SSH public key of the machine";
        type = types.str;
      };
      wg = {
        publicKey = mkOption {
          description = "WireGuard public key of the machine";
          type = types.str;
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
        };
      };
      localIP = mkOption {
        description = "IP of the machine in the local network";
        type = types.nullOr types.str;
      };
      publicIP = mkOption {
        description = "Public IP of the machine";
        type = types.nullOr types.str;
      };
    };
  };
  ip = id: "${cfgWireguard.ipPrefix}.${builtins.toString id}";
in {
  options.settings = with lib; {
    wireguard = {
      server = {
        # * We don't move this to the json config file as none of the other machines need to know such details
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
    hosts = mkOption {
      type = with types; attrsOf (submodule hostOpts);
      description = "Set of hosts to jump to";
      default = {};
    };
    localNetworkId = mkOption {
      description = "SSID of the local network where the machines usually lies";
      type = types.str;
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

    # Load SSH known hosts
    programs.ssh.knownHosts =
      lib.mapAttrs (name: cfg: {
        hostNames =
          [(ip cfg.id)]
          ++ lib.optional (cfg.publicIP != null) cfg.publicIP
          ++ lib.optional (cfg.localIP != null) cfg.localIP;
        publicKey = cfg.sshPublicKey;
      })
      hosts;

    # Configure ssh host aliases
    environment.etc."ssh/ssh_config.d/300-hosts.conf" = {
      text = let
        # Get the SSID of the wifi network, if it exists
        getSSIDCommand =
          if isLinux
          then "iwgetid -r 2>/dev/null || true"
          else "/System/Library/PrivateFrameworks/Apple80211.framework/Resources/airport -I  | awk -F' SSID: '  '/ SSID: / {print $2}'";
      in
        builtins.concatStringsSep "\n" (lib.mapAttrsToList (
            name: cfg: ''
              ${
                # If the machine has a local IP, prefer it over the wireguard tunnel when on the local network
                lib.optionalString (cfg.localIP != null) ''
                  Match Originalhost ${name} Exec "(${getSSIDCommand}) | grep ${config.settings.localNetworkId}"
                    Hostname ${cfg.localIP}
                ''
              }
              Host ${name}
                HostName ${
                # If there is a public IP, prefer it over the wireguard tunnel
                if cfg.publicIP != null
                then cfg.publicIP
                else (ip cfg.id)
              }
            ''
          )
          hosts);
    };
  };
}
