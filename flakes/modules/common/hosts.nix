{lib, ...}: {
  options.settings = with lib; {
    id = mkOption {
      description = "Id of the machine, that will be translated into an IP";
      type = types.int;
      readOnly = true;
    };
    sshPublicKey = mkOption {
      description = "SSH public key of the machine";
      type = types.str;
    };
    publicIP = mkOption {
      description = "Public IP of the machine";
      type = types.nullOr types.str;
      default = null;
    };
    localIP = mkOption {
      description = "IP of the machine in the local network";
      type = types.nullOr types.str;
      default = null;
    };
    builder = {
      enable = mkEnableOption {
        description = "Is the machine a NixOS builder";
      };
    };
    hostsPath = mkOption {
      description = "(INTERNAL) relative path to the hosts files to evaluate the secrets path";
      visible = false;
      # readOnly = true;
      type = types.str;
      default = "./hosts";
    };

    cluster = with lib;
      mkOption {
        description = mdDoc ''
          Config of every machine
        '';
        type = types.attrs;
        default = {};
      };
  };
}
