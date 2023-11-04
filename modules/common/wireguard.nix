{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfgWireguard = config.settings.wireguard;
  hosts = config.settings.hosts;
  host = hosts."${config.networking.hostName}";
  servers = lib.attrsets.filterAttrs (_: cfg: cfg.bastion) hosts;
  clients = lib.attrsets.filterAttrs (_: cfg: !cfg.bastion && host.id != cfg.id) hosts;
  isServer = host.bastion;
  isLinux = pkgs.hostPlatform.isLinux;
  # TODO add a check: darwin machines can't be servers
  hostOpts = {
    name,
    config,
    ...
  }: {
    options = {
      id = mkOption {
        description = "Id of the machine that will be translated into an IP";
        type = types.nullOr types.int;
      };
      sshPublicKey = mkOption {
        description = "SSH public key of the machine";
        type = types.str;
      };
      wgPublicKey = mkOption {
        description = "WireGuard public key of the machine";
        type = types.str;
      };
      # TODO restructure: wireguard: { server: { enable: true, port: 51820 }, publicKey: '...' }
      bastion = mkOption {
        description = "Is the machine a WireGuard bastion";
        type = types.bool;
        default = false;
      };
      ip = mkOption {
        description = "Public IP of the machine";
        type = types.str;
      };
    };
  };
  ip = id: "${cfgWireguard.ipPrefix}.${builtins.toString id}";
  mask = "${ip 0}/24";
in {
  options.settings = {
    wireguard = {
      server = {
        # * We don't move this to the json config file as none of the other machines need to know such details
        externalInterface = mkOption {
          description = "external interface of the bastion";
          type = types.str;
          default = "eth0";
        };
        # TODO move to the JSON config file as clients need to get this information to connect to the server
        port = mkOption {
          description = "port of ssh bastion server";
          type = types.int;
          default = 51820;
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
            # TODO is this 24 vs 32 correct?
            address =
              if isServer
              then ["${ip host.id}/24"]
              else ["${ip host.id}/32"];
            # Path to the private key file.
            privateKeyFile = config.age.secrets.wireguard.path;

            # The port that WireGuard listens to. Must be accessible by the client.
            listenPort = lib.mkIf isServer cfgWireguard.server.port;

            # This allows the wireguard server to route your traffic to the internet and hence be like a VPN
            # For this to work you have to set the dnsserver IP of your router (or dnsserver of choice) in your clients
            # TODO https://www.reddit.com/r/WireGuard/comments/ghp3ap/communicate_between_wireguard_peers/
            # TODO try without this
            postUp = lib.mkIf isServer ''
              ${pkgs.iptables}/bin/iptables -A FORWARD -i wg0 -j ACCEPT
              ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING
              ${pkgs.iptables}/bin/iptables -I FORWARD -i wg0 -o wg0 -j ACCEPT
            '';

            # This undoes the above command
            preDown = lib.mkIf isServer ''
              ${pkgs.iptables}/bin/iptables -D FORWARD -i wg0 -j ACCEPT
              ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING
              ${pkgs.iptables}/bin/iptables -D FORWARD -i wg0 -o wg0 -j ACCEPT
            '';

            peers =
              lib.attrValues
              (
                if isServer
                then
                  lib.mapAttrs (_:cfg: {
                    publicKey = cfg.wgPublicKey;
                    allowedIPs = ["${ip cfg.id}/32"];
                  })
                  clients
                else
                  lib.mapAttrs (_:cfg: {
                    publicKey = cfg.wgPublicKey;
                    allowedIPs = [mask];
                    endpoint = "${cfg.ip}:${builtins.toString cfgWireguard.server.port}"; # ToDo: route to endpoint not automatically configured https://wiki.archlinux.org/index.php/WireGuard#Loop_routing https://discourse.nixos.org/t/solved-minimal-firewall-setup-for-wireguard-client/7577
                    # Send keepalives every 25 seconds. Important to keep NAT tables alive.
                    persistentKeepalive = 25;
                  })
                  servers
              );
          };
        };
      }
      // optionalAttrs isLinux {
        # enable NAT
        nat = lib.mkIf isServer {
          enable = true;
          enableIPv6 = false;
          externalInterface = cfgWireguard.server.externalInterface;
          internalInterfaces = ["wg0"];
        };
        # Open ports in the firewall
        firewall = lib.mkIf isServer {
          allowedUDPPorts = [cfgWireguard.server.port];
        };
      };

    # Load SSH known hosts
    programs.ssh.knownHosts =
      mapAttrs (name: cfg: {
        hostNames = ["${ip cfg.id}" "${cfg.ip}"];
        publicKey = cfg.sshPublicKey;
      })
      hosts;

    # TODO find a way to run a dns server on each bastion, which will resolve the hostnames to the correct IP
    # Configure ssh host aliases
    environment.etc."ssh/ssh_config.d/300-hosts.conf" = {
      # TODO multiple bastions: https://unix.stackexchange.com/questions/720952/is-there-a-possibility-to-add-alternative-jump-servers-in-ssh-config
      text = builtins.concatStringsSep "\n" (mapAttrsToList (
          name: cfg: ''
            Match Originalhost ${name} Exec "ifconfig | grep ${host.ip}"
              Hostname ${cfg.ip}
            Host ${name}
              HostName ${ip cfg.id}
          ''
        )
        hosts);
    };
  };
}
