{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  isDarwin = pkgs.hostPlatform.isDarwin;
  isLinux = pkgs.hostPlatform.isLinux;
  cfgBastion = config.settings.bastion;
  cfgTunnel = config.settings.tunnel;
  cfgHosts = config.settings.hosts;
  hostOpts = {
    name,
    config,
    ...
  }: {
    options = {
      tunnelId = mkOption {
        description = "port";
        type = types.nullOr types.int;
      };
      publicKey = mkOption {
        description = "public key";
        type = types.str;
      };
      ip = mkOption {
        description = "ip address";
        type = types.str;
      };
    };
  };
in {
  options.settings = {
    bastion = {
      enable = mkEnableOption "is this machine a bastion";
      user = {
        name = mkOption {
          description = "username user for tunnelling";
          type = types.str;
          default = "tunneller";
        };
        privateKeyFile = mkOption {
          description = "path to the private key";
          type = types.str;
          default = "/etc/ssh/tunneller";
        };
        keys = mkOption {
          type = types.listOf types.str;
          default = [];
          description = "SSH public keys for the bastion user";
        };
      };
      host = mkOption {
        description = "host name of the tunnel";
        type = types.str;
        default = ""; # TODO only required if enabled
      };
      port = mkOption {
        description = "port of ssh bastion server";
        type = types.int;
        default = 22;
      };
    };
    tunnel = {
      enable = mkEnableOption "is this machine connected to a bastion";
      port = mkOption {
        description = "port of the tunnel in the bastion";
        type = types.int;
        default = 9000;
      };
    };
    hosts = mkOption {
      type = with types; attrsOf (submodule hostOpts);
      description = "Set of hosts to jump to";
      default = {};
    };
  };

  config = {
    services =
      optionalAttrs cfgTunnel.enable {
        autossh.sessions = [
          {
            extraArguments = "-N -R ${builtins.toString cfgTunnel.port}:localhost:${builtins.toString cfgBastion.port} -i ${cfgBastion.user.privateKeyFile} -o \"ServerAliveInterval 30\" -o \"ServerAliveCountMax 3\" ${cfgBastion.user.name}@${cfgBastion.host}";
            name = "tunnel";
            user = cfgBastion.user.name;
          }
        ];
      }
      // optionalAttrs cfgBastion.enable {
        openssh = {
          enable = true;
          extraConfig = ''
            Match User ${cfgBastion.user.name}
              AllowTcpForwarding yes
              X11Forwarding no
              AllowAgentForwarding no
              ForceCommand /bin/false
          '';
        };
      };

    users =
      mkIf (cfgTunnel.enable || cfgBastion.enable)
      (
        {
          users.${cfgBastion.user.name} =
            {
              uid = 550; #! arbitrary
              name = cfgBastion.user.name;
              createHome = false;
              openssh.authorizedKeys.keys = mkIf cfgBastion.enable cfgBastion.user.keys;
            }
            // optionalAttrs isLinux {
              isSystemUser = mkIf isLinux true;
              group = "nogroup";
            };
        }
        // optionalAttrs isDarwin {
          knownUsers = [cfgBastion.user.name];
        }
      );

    # ? Is it really needed everywhere, or only in the bastion?
    # Load SSH known hosts
    programs.ssh.knownHosts =
      mapAttrs (name: cfg: {
        hostNames =
          [cfg.ip]
          ++ (
            if cfg.tunnelId != null
            then ["[localhost]:${builtins.toString cfg.tunnelId}"]
            else []
          );
        publicKey = cfg.publicKey;
      })
      cfgHosts;

    environment.etc."ssh/ssh_config.d/200-tunneller.conf" = mkIf cfgTunnel.enable {
      text = ''
        Match User ${cfgBastion.user.name}
          IdentityFile ${cfgBastion.user.privateKeyFile}
          IdentitiesOnly yes
      '';
    };

    # Configure ssh host aliases
    environment.etc."ssh/ssh_config.d/300-jumps.conf" = {
      # TODO proxyjump: try to connect directly to the host, if it fails, try to connect through the bastion
      # TODO multiple bastions: https://unix.stackexchange.com/questions/720952/is-there-a-possibility-to-add-alternative-jump-servers-in-ssh-config
      text = builtins.concatStringsSep "\n" (mapAttrsToList (name: cfg:
        if (cfg.tunnelId == null || !cfgTunnel.enable)
        then ''
          Host ${name}
            HostName ${cfg.ip}
        ''
        else ''
          Host ${name}
            HostName localhost
            Port ${builtins.toString cfg.tunnelId}
            ProxyJump ${cfgBastion.host}
        '')
      cfgHosts);
    };
  };
}
