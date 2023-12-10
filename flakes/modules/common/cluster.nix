{lib, ...}: {
  options.cluster = with lib; {
    hosts = {
      # TODO make sure that the id is unique
      # TODO check on cfg.cluster.hosts.config.<name>.id
      config = mkOption {
        description = "(INTERNAL) Config of every machine";
        type = types.attrs;
        default = {};
        visible = false;
        # readOnly = true;
      };
      nixosPath = mkOption {
        description = "(INTERNAL) relative path to the NixOS hosts files";
        type = types.str;
        default = "./hosts-nixos";
        visible = false;
        # readOnly = true;
      };
      darwinPath = mkOption {
        description = "(INTERNAL) relative path to the Darwin hosts files";
        type = types.str;
        default = "./hosts-darwin";
        visible = false;
        # readOnly = true;
      };
    };
    secrets = {
      config = mkOption {
        description = "(INTERNAL) Agenix secrets configuration";
        type = types.attrs;
        default = {};
        visible = false;
        # readOnly = true;
      };
    };
    users = {
      config = mkOption {
        description = "(INTERNAL) users configuration";
        type = types.attrs;
        default = {};
        visible = false;
        # readOnly = true;
      };
      path = mkOption {
        description = "(INTERNAL) relative path to users file";
        type = types.str;
        default = "./users";
        visible = false;
        # readOnly = true;
      };
      # TODO check if not empty, that all users exist and they all have a public key
      admins = mkOption {
        description = "(INTERNAL) list of the users that are administators of the cluster";
        type = types.listOf types.str;
        default = [];
        visible = false;
        # readOnly = true;
      };
    };
    wifi = {
      path = mkOption {
        description = "(INTERNAL) relative path to the wifi configuration";
        type = types.nullOr types.str;
        visible = false;
        # readOnly = true;
      };
    };
  };
}
