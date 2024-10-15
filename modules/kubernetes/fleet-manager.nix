{
  config,
  lib,
  pkgs,
  cluster,
  ...
}:
with lib; let
  inherit (config.settings) kubernetes tailnet;
  cfg = config.settings.fleet-manager;
  # TODO how to keep in sync with the fleet version of the custom chart?
  helmChartVersion = "0.9.3";
  clustersNamespace = "clusters";

  downstream =
    filterAttrs
    (name: h: h.settings.kubernetes.enable && !h.settings.fleet-manager.enable)
    cluster.hosts;
in {
  options.settings.fleet-manager = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "This Cluster is the Fleet Manager";
    };
  };

  config = mkIf (cfg.enable) {
    # TODO there should be only one fleet-manager
    assertions = [
      {
        assertion = kubernetes.enable;
        message = "Fleet requires Kubernetes to be enabled.";
      }
    ];

    settings.git.repos = {
      # * Create a local git repo for the fleet directory (it will be available through the git-daemon k8s service)
      fleet = ../../fleet;

      # * Similary, create a local repo with the packaged helm charts so they can be used in fleet.yaml definitions
      charts = pkgs.symlinkJoin {
        name = "charts";
        paths =
          foldlAttrs
          (acc: name: type: acc ++ optional (type == "directory") (pkgs.helm-package name (../../charts + "/${name}")))
          [] (builtins.readDir ../../charts);
      };
    };

    # * Install the Fleet Manager and CRD as a k3s manifest if Fleet runs on upstream mode
    system.activationScripts = {
      kubernetes-fleet-manager.text = ''
        ${pkgs.k3s-chart {
          name = "fleet-crd";
          namespace = "cattle-fleet-system";
          repo = "https://rancher.github.io/fleet-helm-charts";
          chart = "fleet-crd";
          version = helmChartVersion;
        }}
        ${pkgs.k3s-chart {
          name = "fleet";
          namespace = "cattle-fleet-system";
          src = ../../charts/fleet-manager;
        }}
      '';
    };

    # * Update the fleet helm values in the k3s manifests after the k3s service is up, so it gets the correct CA certificate
    systemd.services.k3s-fleet-config = {
      wantedBy = ["multi-user.target"];
      after = ["k3s.service"];
      wants = ["k3s.service"];
      description = "update the fleet config";
      environment = {
        KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = let
          clusterConfig = host: {
            # TODO namespace labels, and remove them from the local cluster
            labels = host.settings.kubernetes.labels;
            values =
              {
                hostname = host.networking.hostName;
              }
              // host.settings.kubernetes.values;
          };
          values = pkgs.writeText "values.json" (strings.toJSON chartValues);
          chartValues = {
            inherit tailnet;
            downstream = {
              namespace = clustersNamespace;
              clusters =
                mapAttrsToList (name: host: {
                  inherit name;
                  inherit (clusterConfig host) labels values;
                })
                downstream;
            };

            local = clusterConfig config;

            gitRepos = [
              {
                name = "downstream";
                namespace = clustersNamespace;
                repo = "git://git-daemon.cattle-fleet-system/fleet";
                paths = ["*"];
                branch = "main";
                targets = [{clusterSelector = {};}];
              }
              {
                name = "local";
                namespace = "fleet-local";
                repo = "git://git-daemon.cattle-fleet-system/fleet";
                paths = ["*"];
                branch = "main";
                targets = [{clusterSelector = {};}];
              }
            ];
            gitDaemon = {
              enabled = true;
              localPath = config.settings.git.basePath;
            };
            fleet = {
              apiServerURL = "https://cluster-${config.networking.hostName}.${tailnet}:443";
              apiServerCA = "ref+envsubst://$CA_DATA";
            };
          };
        in
          pkgs.writeShellScript "set-fleet-config" ''
            while true; do
              CONFIG=$(${pkgs.kubectl}/bin/kubectl config view -o json --raw)
              if echo "$CONFIG" | ${pkgs.jq}/bin/jq '.clusters | length' | grep -q '^0$'; then
                echo "Error: No cluster found in kubeconfig."
                sleep 1
              else
                break
              fi
            done
            export CA_DATA=$(echo "$CONFIG" | ${pkgs.jq}/bin/jq -r '.clusters[].cluster["certificate-authority-data"]' | base64 -d)
            ${pkgs.k3s-chart-config "fleet"} "$(${pkgs.vals}/bin/vals eval -f ${values})"
          '';
        Restart = "on-failure";
        RestartSec = 3;
        RemainAfterExit = "no";
      };
    };

    # downstream servers should be able to reach the upstream k3s API to register to the fleet
    networking.firewall.allowedTCPPorts = [6443];
  };
}
