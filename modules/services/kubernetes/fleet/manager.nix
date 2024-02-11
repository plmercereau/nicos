{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  k8s = config.settings.services.kubernetes;
  fleet = k8s.fleet;
  isManager = fleet.mode != "downstream";
  isUpstream = fleet.mode == "upstream";
  isMultiCluster = fleet.mode != "standalone";
in {
  options = {
    settings.services.kubernetes.fleet = let
      gitRepoTypeOptions = {
        namespace = mkOption {
          type = types.str;
          default = "default";
          description = "namespace of the git repository";
        };
        branch = mkOption {
          type = types.str;
          default = "main";
          description = "branch of the git repository";
        };
        paths = mkOption {
          type = types.listOf types.str;
          default = ["*"];
          description = "paths to be included in the git repository";
        };
        targets = mkOption {
          type = types.listOf types.attrs; # TODO better type
          default = [];
          description = "";
        };
      };
    in {
      localGitRepos = mkOption {
        type = types.attrsOf (types.submodule {
          options =
            gitRepoTypeOptions
            // {
              package = mkOption {
                type = types.path;
                description = "TODO";
              };
            };
        });
        default = {};
        description = "TODO";
      };
      gitRepos = mkOption {
        type = types.attrsOf (types.submodule {
          options =
            gitRepoTypeOptions
            // {
              repo = mkOption {
                type = types.str;
                description = "URL of the git repository";
              };
            };
        });
        default = {};
        description = "TODO";
      };
    };
  };

  config = mkIf (k8s.enable && fleet.enable && isManager) {
    assertions = [
      {
        assertion = !(isMultiCluster && !config.settings.networking.vpn.enable);
        message = "Fleet requires the VPN to be enabled to work in multi-cluster mode (${fleet.mode}).";
      }
    ];

    # * Install the Fleet Helm chart and CRD as a k3s manifest if Fleet runs on upstream or standalone mode
    system.activationScripts.kubernetes-fleet.text = let
      dest = "/var/lib/rancher/k3s/server/manifests";
      chart = pkgs.writeText "chart.yaml" ''
        apiVersion: v1
        kind: Namespace
        metadata:
          name: ${fleet.clustersNamespace}
        ---
        apiVersion: v1
        kind: Namespace
        metadata:
          name: ${fleet.fleetNamespace}
        ---
        apiVersion: helm.cattle.io/v1
        kind: HelmChart
        metadata:
          name: fleet-crd
          namespace: kube-system
        spec:
          repo: https://rancher.github.io/fleet-helm-charts
          chart: fleet-crd
          targetNamespace: ${fleet.fleetNamespace}
        ---
        apiVersion: helm.cattle.io/v1
        kind: HelmChart
        metadata:
          name: fleet
          namespace: kube-system
        spec:
          repo: https://rancher.github.io/fleet-helm-charts
          chart: fleet
          targetNamespace: ${fleet.fleetNamespace}
      '';
    in ''
      mkdir -p ${dest}
      ln -sf ${chart} ${dest}/fleet.yaml
    '';

    settings.services.kubernetes.fleet.localGitRepos = {
      # * Create a local git repo + Fleet GitRepo resource for the local cluster
      local = {
        namespace = "fleet-local";
        package = ../../../../fleet;
        targets = [
          {
            name = "default";
            clusterName = "local";
          }
        ];
      };

      # * Add a local git repo + Fleet GitRepo resource for all the downstream clusters
      downstream-fleet = {
        namespace = fleet.clustersNamespace;
        package = ../../../../fleet;
        targets = [
          {
            name = "default";
            clusterSelector = {};
          }
        ];
      };
    };
  };
}
