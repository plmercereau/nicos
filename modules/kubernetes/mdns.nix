{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.settings.services.kubernetes.mdns;
in {
  imports = [./fleet ./vpn.nix];

  options.settings.services.kubernetes = {
    mdns.enable = mkOption {
      type = types.bool;
      default = !config.settings.services.kubernetes.fleet.enable || config.settings.services.kubernetes.fleet.mode != "upstream";
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
