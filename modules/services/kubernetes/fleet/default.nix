{
  config,
  lib,
  pkgs,
  cluster,
  ...
}:
with lib; let
  k8s = config.settings.services.kubernetes;
  fleet = k8s.fleet;
  isMultiCluster = fleet.mode != "standalone";
in {
  imports = [./upstream.nix ./downstream.nix ./manager.nix];
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
    connectionUser = mkOption {
      type = types.str;
      default = "fleet-connection-user";
      description = "User to connect to the upstream machine and patch the kubeconfig secret of the downstream cluster";
    };
    labels = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Labels to add to the cluster when running in multi-cluster mode";
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
    assertions = mkIf (k8s.enable && fleet.enable && isMultiCluster) [
      {
        # TODO remove this check, but first:
        # 1. find a way to make gitrepos work without providing the host IP: either run git daemon on k8s or bridge network
        # 2. create an option to get the upstream host (both for the fleet registration and ssh handshake)
        # ? use publicIP, localIP, vpn IP?
        assertion = config.settings.networking.vpn.enable;
        message = "Fleet requires the VPN to be enabled to work in multi-cluster mode (${fleet.mode}).";
      }
    ];
  };
}
