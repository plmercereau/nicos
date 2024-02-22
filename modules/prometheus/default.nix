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
    upstream = {
      enable = mkOption {
        description = ''
          Enable Prometheus in upstream mode.
        '';
        type = types.bool;
        default = true;
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      # TODO kubernetes must be enabled
      # TODO only one upstream
    ];
    settings.kubernetes.fleet.labels.prometheus =
      if cfg.upstream.enable
      then "upstream"
      else "downstream";
  };
}
