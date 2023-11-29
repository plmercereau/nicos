{lib, ...}: let
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
      platform = mkOption {
        description = "Platform of the machine";
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
      builder = mkEnableOption {
        description = "Is the machine a NixOS builder";
      };
      publicIP = mkOption {
        description = "Public IP of the machine";
        type = types.nullOr types.str;
      };
    };
  };
in {
  options.settings = with lib; {
    hosts = mkOption {
      type = with types; attrsOf (submodule hostOpts);
      description = "Set of hosts to jump to";
      default = {};
    };
  };
}
