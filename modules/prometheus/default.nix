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
        Label the machine as using the Prometheus monitoring system.

        By default, the machine is labeled when the Kubernetes cluster is enabled.
      '';
      type = types.bool;
      default = config.settings.kubernetes.enable;
    };

    federation = {
      enable = mkOption {
        description = ''
          Label the machine as using Prometheus in a federation of multiple Prometheus instances.
        '';
        type = types.bool;
        default = true;
      };
      upstream = {
        enable = mkOption {
          description = ''
            Label the machine as being the upstream Prometheus instance in a federation.
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
    settings.kubernetes.labels.prometheus =
      if !cfg.federation.enable
      then "standalone"
      else if cfg.federation.upstream.enable
      then "upstream"
      else "downstream";
  };
}
