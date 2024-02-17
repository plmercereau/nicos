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
          type = types.listOf types.attrs; # TODO better type, but avoid having to replicate the entire fleet.yaml schema
          default = [];
          description = "Target clusters to deploy the GitRepo to. If none is specified, nothing will be deployed.";
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
                description = "Local path that will be used as the git repository";
              };
            };
        });
        default = {};
        description = ''
          Set of local paths to be used as git repositories for Fleet.
              
          For each entry, a GitRepo will be created and will point to a repo served by a git daemon running on the host machine.'';
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
        description = ''
          List of Git repositories to add to Fleet as GitRepo resources.

          Each resource will be built as a derivation, then symlinked as a K3s addon manifest on system activation.
        '';
      };
    };
  };

  config = mkIf (k8s.enable && fleet.enable && isManager) {
    settings.services.kubernetes.fleet.localGitRepos = {
      # ! spec.templateValues is not interpolated by fleet in the fleet-local/local cluster. File an issue.
      # ! Labels work, but we can only use them for string values.
      # * NB: we cannot register the local cluster elsewhere: https://fleet.rancher.io/troubleshooting#migrate-the-local-cluster-to-the-fleet-default-cluster-workspace
      # * Create a local git repo + Fleet GitRepo resource for the local cluster
      local = {
        namespace = "fleet-local";
        package = ../../../../fleet;
        targets = [{clusterName = "local";}];
      };

      # * Add a local git repo + Fleet GitRepo resource for all the downstream clusters
      downstream-fleet = {
        namespace = fleet.clustersNamespace;
        package = ../../../../fleet;
        targets = [{clusterSelector = {};}];
      };
    };

    # * Sync any potential local git repos to the git daemon
    settings.services.gitDaemon.repos =
      mapAttrs'
      (name: localRepo: nameValuePair "fleet-${name}" localRepo.package)
      fleet.localGitRepos;

    # * Any local git repo is registered as a fleet git repo
    settings.services.kubernetes.fleet.gitRepos = mapAttrs' (name: localRepo:
      nameValuePair "local-${name}"
      {
        inherit (localRepo) namespace branch paths targets;
        repo = "git://${config.lib.vpn.ip}:${toString config.services.gitDaemon.port}/fleet-${name}";
      })
    fleet.localGitRepos;

    system.activationScripts = mkMerge [
      # * Create a symlink to every git repo manifest in the k3s server manifests directory
      (mapAttrs' (name: gitRepo:
        nameValuePair "symlink-git-repo-manifest-${name}" {
          text = let
            manifest = pkgs.writeText "git-repo-${name}.yaml" ''
              kind: GitRepo
              apiVersion: fleet.cattle.io/v1alpha1
              metadata:
                  name: ${name}
                  namespace: ${gitRepo.namespace}
              spec:
                  repo: ${gitRepo.repo}
                  branch: ${gitRepo.branch}
                  paths: ${strings.toJSON gitRepo.paths}
                  targets: ${strings.toJSON gitRepo.targets}
            '';
            dest = "/var/lib/rancher/k3s/server/manifests";
          in ''
            mkdir -p ${dest}
            ln -sf ${manifest} ${dest}/fleet-git-repo-${name}.yaml
          '';
        })
      fleet.gitRepos)
      {
        # * Install the Fleet Manager and CRD as a k3s manifest if Fleet runs on upstream or standalone mode
        kubernetes-fleet-manager.text = let
          dest = "/var/lib/rancher/k3s/server/manifests";
          chart = pkgs.writeText "chart.yaml" ''
            apiVersion: v1
            kind: Namespace
            metadata:
              name: ${fleet.clustersNamespace}
            ---
            apiVersion: helm.cattle.io/v1
            kind: HelmChart
            metadata:
              name: fleet-crd
              namespace: kube-system
            spec:
              repo: https://rancher.github.io/fleet-helm-charts
              chart: fleet-crd
              version: ${fleet.helmChartVersion}
              targetNamespace: ${fleet.fleetNamespace}
              createNamespace: true
            ---
            apiVersion: helm.cattle.io/v1
            kind: HelmChart
            metadata:
              name: fleet
              namespace: kube-system
            spec:
              repo: https://rancher.github.io/fleet-helm-charts
              chart: fleet
              version: ${fleet.helmChartVersion}
              targetNamespace: ${fleet.fleetNamespace}
              createNamespace: true
            ---
            kind: Cluster
            apiVersion: fleet.cattle.io/v1alpha1
            metadata:
              name: local
              namespace: fleet-local
              labels: ${strings.toJSON fleet.labels}
            spec:
              templateValues: ${strings.toJSON fleet.values}
          '';
        in ''
          mkdir -p ${dest}
          ln -sf ${chart} ${dest}/fleet.yaml
        '';
      }
    ];
  };
}
