{
  config,
  lib,
  pkgs,
  cluster,
  ...
}:
with lib; let
  k8s = config.settings.services.kubernetes;
  cfg = k8s.fleet;
in {
  imports = [./upstream.nix ./downstream.nix ./git-repos.nix ./manager.nix];
  options.settings.services.kubernetes.fleet = {
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
    clustersNamespace = mkOption {
      type = types.str;
      default = "clusters";
      description = "Namespace where the clusters are defined when running in upstream mode";
    };
    mode = mkOption {
      type = types.enum ["standalone" "upstream" "downstream"];
      default = "standalone";
      description = ''
        Fleet mode.
        Standalone will install the manager and agent on the same node, and will manage its own applications.
        Upstream will install the manager, and will manage applications on downstream clusters. There should be only one upstream cluster in the project.
        Downstream will install the agent, and will manage applications on the upstream cluster. An upstream cluster is required in the project.
      '';
    };
    labels = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Labels to add to the cluster when running in multi-cluster mode";
    };
  };
}
