{
  config,
  lib,
  pkgs,
  cluster,
  ...
}:
with lib; let
  inherit (config.settings) kubernetes fleet;
  cfg = fleet.upstream;
  inherit (config.lib.fleet) downstream;

  chartValues = let
    clusterConfig = host: {
      # TODO namespace labels, and remove them from the local cluster
      labels = host.settings.fleet.labels;
      values =
        {
          hostname = host.networking.hostName;
        }
        // host.settings.fleet.values;
    };
  in {
    downstream = {
      namespace = cfg.clustersNamespace;
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
        namespace = cfg.clustersNamespace;
        repo = "git://git-daemon.${fleet.fleetNamespace}/fleet";
        paths = ["*"];
        branch = "main";
        targets = [{clusterSelector = {};}];
      }
      {
        name = "local";
        namespace = "fleet-local";
        repo = "git://git-daemon.${fleet.fleetNamespace}/fleet";
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
      # apiServerURL = "https://${ip}:6443"; # TODO tailscale
      apiServerCA = "ref+envsubst://$CA_DATA";
    };
  };
in {
  options.settings.fleet.upstream = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable the upstream mode for the fleet";
    };
    clustersNamespace = mkOption {
      type = types.str;
      default = "clusters";
      description = "Namespace where the clusters are defined.";
    };
  };
  config = mkIf (fleet.enable && cfg.enable) {
    assertions = [
      # TODO only one active upstream machine in the cluster
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
          namespace = fleet.fleetNamespace;
          repo = "https://rancher.github.io/fleet-helm-charts";
          chart = "fleet-crd";
          version = fleet.helmChartVersion;
        }}
        ${pkgs.k3s-chart {
          name = "fleet";
          namespace = fleet.fleetNamespace;
          src = ../../charts/fleet-manager; # TODO how to keep in sync with the fleet version?
        }}
      '';
    };

    # * Update the fleet helm values in the k3s manifests after the k3s service is up, so it gets the correct CA certificate
    systemd.services.k3s-fleet-config = let
    in {
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
          values = pkgs.writeText "values.json" (strings.toJSON chartValues);
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

    networking.firewall = {
      allowedTCPPorts =
        # downstream servers should be able to reach the upstream k3s API to register to the fleet
        [6443]
        # downstream servers should connect to upstream through ssh in order to get a ClusterRegistrationToken
        ++ config.services.openssh.ports;
    };
  };
}
