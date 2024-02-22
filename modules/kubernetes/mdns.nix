{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.settings.kubernetes.mdns;
in {
  options.settings.kubernetes = {
    mdns.enable = mkOption {
      type = types.bool;
      default = !config.settings.fleet.enable || !config.settings.fleet.upstream.enable;
      description = ''
        Enable the broadcasting of services using mDNS.

        Is enabled by default if Fleet is disabled or in "downstream" mode.
      '';
    };
  };

  config = mkIf cfg.enable {
    system.activationScripts.kubernetes.text = mkAfter ''
      ${
        pkgs.k3s-chart {
          name = "external-mdns";
          namespace = "kube-system";
          src = ../../charts/external-mdns;
        }
      }
    '';
  };
}
