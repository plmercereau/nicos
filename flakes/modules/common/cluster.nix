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
        type = types.nullOr types.str;
        visible = false;
        # readOnly = true;
      };
      darwinPath = mkOption {
        description = "(INTERNAL) relative path to the Darwin hosts files";
        type = types.nullOr types.str;
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
      path = mkOption {
        description = "(INTERNAL) relative path to users file";
        type = types.nullOr types.str;
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
