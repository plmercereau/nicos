{
  config,
  lib,
  pkgs,
  cluster,
  ...
}:
with lib; let
  cfg = config.settings.prometheus;
in {
  options.settings.prometheus = {
    enable = mkOption {
      description = ''
        Enable the Prometheus monitoring system.

        By default, Prometheus is enabled when the Kubernetes cluster is enabled.
      '';
      type = types.bool;
      default = config.settings.kubernetes.enable;
    };

    federation = {
      enable = mkOption {
        description = ''
          Enable federation accross multiple Prometheus instances.
        '';
        type = types.bool;
        default = true;
      };
      upstream = {
        enable = mkOption {
          description = ''
            This machine is the upstream federation node
          '';
          type = types.bool;
          default = true;
        };
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      # TODO kubernetes must be enabled
      # TODO only one upstream
    ];
    settings.fleet.labels.prometheus =
      if !cfg.federation.enable
      then "standalone"
      else if cfg.federation.upstream.enable
      then "upstream"
      else "downstream";
  };
}
