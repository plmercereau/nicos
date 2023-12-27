{
  lib,
  config,
  ...
}:
with lib; let
  inherit (config.lib) ext_lib;
  hardwareOpts = {
    name,
    config,
    ...
  }: {
    options = {
      description = mkOption {
        description = "Description of the hardware";
        type = types.str;
      };
      path = mkOption {
        description = "Path to the hardware configuration";
        type = types.path;
      };
    };
  };
in {
  options = {
    settings.id = mkOption {
      description = "Id of the machine, that will be translated into an IP";
      type = types.int;
      readOnly = true;
    };
    cluster = {
      hosts = {
        config = mkOption {
          description = "(INTERNAL) Config of every machine";
          type = types.attrs;
          default = {};
          visible = false;
        };
        nixos = {
          enable = mkOption {
            description = "(INTERNAL) Enable NixOS on the cluster";
            type = types.bool;
            default = false;
            visible = false;
          };
          path = mkOption {
            description = "(INTERNAL) relative path to the NixOS hosts files";
            type = types.nullOr types.str;
            visible = false;
            # readOnly = true;
          };
        };
        darwin = {
          enable = mkOption {
            description = "(INTERNAL) Enable Darwin on the cluster";
            type = types.bool;
            default = false;
            visible = false;
          };
          path = mkOption {
            description = "(INTERNAL) relative path to the Darwin hosts files";
            type = types.nullOr types.str;
            visible = false;
            # readOnly = true;
          };
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
        adminKeys = mkOption {
          description = "(INTERNAL) Cluster admin keys";
          type = with types; listOf ext_lib.pub_key_type; # TODO must have at least one value
          default = [];
          visible = false;
          # readOnly = true;
        };
      };

      hardware = {
        nixos = mkOption {
          type = with types; attrsOf (submodule hardwareOpts);
          description = "Information about the hardware of the NixOS machines";
          default = {};
          visible = false;
        };
        darwin = mkOption {
          type = with types; attrsOf (submodule hardwareOpts);
          description = "Information about the hardware of the Darwin machines";
          default = {};
          visible = false;
        };
      };
    };
  };
}
