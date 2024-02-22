{
  config,
  lib,
  pkgs,
  cluster,
  ...
}:
with lib; let
  inherit (config.settings) kubernetes;
  inherit (kubernetes) fleet;
  cfg = fleet.upstream;
  inherit (config.lib.kubernetes) ip;
  inherit (config.lib.fleet) downstream;

  chartValues = let
    clusterConfig = host: {
      labels = host.settings.kubernetes.fleet.labels;
      values = host.settings.kubernetes.fleet.values // {name = host.networking.hostName;};
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
      apiServerURL = "https://${ip}:6443";
      apiServerCA = "ref+envsubst://$CA_DATA";
    };
  };
in {
  options.settings.kubernetes.fleet.upstream = {
    enable = mkOption {
      # TODO assertion: only one active upstream machine in the cluster
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
  config = mkIf (kubernetes.enable && fleet.enable && cfg.enable) {
    # * Sync any potential local git repos to the git daemon
    settings.git.repos.fleet = ../../../fleet;

    # * Install the Fleet Manager and CRD as a k3s manifest if Fleet runs on upstream mode
    system.activationScripts = {
      kubernetes-fleet-manager.text = ''
        ${pkgs.k3s-chart {
          name = "fleet-crd";
          namespace = fleet.fleetNamespace;
          repo = "https://rancher.github.io/fleet-helm-charts";
          chart = "fleet-crd";
          version = "0.9.0"; # TODO how to keep in sync with the fleet version?
        }}
        ${pkgs.k3s-chart {
          name = "fleet";
          namespace = fleet.fleetNamespace;
          src = ../../../charts/fleet-manager;
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

    # * Add the user that the downstream machines will use to send their kubeconfig, and secure it with only allowing a determined command
    users.users.${fleet.connectionUser} = {
      isSystemUser = true;
      shell = pkgs.bash;
      group = fleet.connectionUser;
      extraGroups = [kubernetes.group];
      /*
      Each downstream cluster is allowed to create a cluster registration for itself through ssh.
      The ssh command returns the registration token to be used in the cluster registration
      The command is secured by public/private key authentication and by only allowing the command to be executed
      */
      openssh.authorizedKeys.keys = mapAttrsToList (name: value: let
        ns = cfg.clustersNamespace;
        registrationToken = pkgs.writeText "" ''
          kind: ClusterRegistrationToken
          apiVersion: "fleet.cattle.io/v1alpha1"
          metadata:
            name: ${name}-token
            namespace: ${ns}
          spec:
            ttl: 15m
        '';
        command = pkgs.writeScript "create-token-values" ''
          set -e
          ${pkgs.kubectl}/bin/kubectl apply -f ${registrationToken} > /dev/null 2>&1
          while ! ${pkgs.kubectl}/bin/kubectl --namespace=${ns} get secret ${name}-token > /dev/null 2>&1; do sleep 1; done
          CLIENT_ID=$(${pkgs.kubectl}/bin/kubectl --namespace=${ns} get cluster ${name} -o 'jsonpath={.spec.clientID}')
          if [ -z "$CLIENT_ID" ]; then
            CLIENT_ID=$(${pkgs.util-linux}/bin/uuidgen)
            ${pkgs.kubectl}/bin/kubectl patch cluster ${name} --namespace=${ns} --type=merge -p "{\"spec\":{\"clientID\":\"$CLIENT_ID\"}}" > /dev/null 2>&1
          fi
          ${pkgs.kubectl}/bin/kubectl --namespace=${ns} get secret ${name}-token -o 'jsonpath={.data.values}' | base64 --decode
          echo "clientID: $CLIENT_ID"
        '';
      in ''command="${command}" ${value.settings.sshPublicKey}'')
      downstream;
    };

    users.groups.${fleet.connectionUser} = {};
  };
}
