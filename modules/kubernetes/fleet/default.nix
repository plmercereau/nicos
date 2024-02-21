{
  config,
  lib,
  pkgs,
  cluster,
  ...
}:
with lib; let
  k8s = config.settings.kubernetes;
  fleet = k8s.fleet;
in {
  imports = [./upstream.nix ./downstream.nix];
  options.settings.kubernetes.fleet = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable fleet";
    };
    fleetNamespace = mkOption {
      type = types.str;
      default = "fleet-system";
      description = "Namespace where fleet will run";
    };
    connectionUser = mkOption {
      type = types.str;
      default = "fleet-connection-user";
      description = "User to connect to the upstream machine and patch the kubeconfig secret of the downstream cluster";
    };
    labels = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Labels to add to the cluster";
    };
    values = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Template values of the cluster";
    };
    helmChartVersion = mkOption {
      type = types.str;
      default = "0.9.0";
      description = "Fleet Helm chart version";
    };
  };

  config = {
    assertions = mkIf (k8s.enable && fleet.enable) [
      {
        assertion = config.settings.vpn.enable;
        message = "Fleet requires the VPN to be enabled.";
      }
    ];
  };
}
