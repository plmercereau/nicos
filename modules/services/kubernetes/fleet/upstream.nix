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
  isUpstream = fleet.mode == "upstream";

  downstreamMachines = filterAttrs (name: h: h.nixpkgs.hostPlatform.isLinux && h.settings.services.kubernetes.fleet.mode == "downstream") cluster.hosts;
in {
  options = {
    settings.services.kubernetes.fleet = {
      connectionUser = mkOption {
        type = types.str;
        default = "fleet-connection-user";
        description = "User to connect to the upstream machine and patch the kubeconfig secret of the downstream cluster";
      };
    };
  };

  config = mkIf (k8s.enable && fleet.enable && isUpstream) {
    # TODO assertion: only one active upstream machine in the cluster

    # * Add a local git repo and a Fleet GitRepo resource qith all the downstream clusters
    settings.services.kubernetes.fleet.localGitRepos.downstream-clusters = {
      namespace = "fleet-local";
      package =
        pkgs.runCommand "downstream-clusters" {}
        (foldlAttrs (acc: name: host: let
            inherit (host.networking) hostName;
            inherit (host.settings.services.kubernetes.fleet) labels values;
          in ''
            ${acc}
            cat <<'EOF' >> $out/clusters/clusters.yaml
            kind: Cluster
            apiVersion: fleet.cattle.io/v1alpha1
            metadata:
              name: ${hostName}
              namespace: ${fleet.clustersNamespace}
              labels: ${strings.toJSON labels}
            spec:
              kubeConfigSecret: ${hostName}-kubeconfig
              templateValues: ${strings.toJSON values}
            ---
            EOF
          '')
          ''
            mkdir -p $out/clusters
          ''
          downstreamMachines);
      paths = ["clusters"];
      targets = [
        {
          name = "default";
          clusterName = "local";
        }
      ];
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
          fleetConfig = pkgs.writeText "fleet-config.yaml" ''
            apiVersion: helm.cattle.io/v1
            kind: HelmChartConfig
            metadata:
              name: fleet
              namespace: kube-system
            spec:
              set:
                apiServerURL: https://${config.lib.vpn.ip}:6443
          '';
        in
          pkgs.writeShellScript "set-fleet-config" ''
            while true; do
              CONFIG=$(${pkgs.kubectl}/bin/kubectl config view -o json --raw)
              if echo "$CONFIG" | ${pkgs.jq}/bin/jq '.clusters | length' | grep -q '^0$'; then
                echo "Error: No clusters found in kubeconfig."
                sleep 1
              else
                break
              fi
            done
            CA_DATA=$(echo "$CONFIG" | ${pkgs.jq}/bin/jq -r '.clusters[].cluster["certificate-authority-data"]' | base64 -d)
            ${pkgs.yq-go}/bin/yq e -o=json ${fleetConfig} | ${pkgs.jq}/bin/jq --arg ca_data "$CA_DATA" '.spec.set.apiServerCA = $ca_data' > /var/lib/rancher/k3s/server/manifests/fleet-config.yaml
          '';
        Restart = "on-failure";
        RestartSec = 3;
        RemainAfterExit = "no";
      };
    };

    # * Add the user that the downstream machines will use to send their kubeconfig, and secure it with only allowing a determined command
    users.users.${fleet.connectionUser} = {
      isSystemUser = true;
      shell = pkgs.bash;
      group = fleet.connectionUser;
      extraGroups = [k8s.group];
      openssh.authorizedKeys.keys = mapAttrsToList (name: value: let
        resource = pkgs.writeText "" ''
          kind: Secret
          apiVersion: v1
          metadata:
            name:  ${name}-kubeconfig
            namespace: ${fleet.clustersNamespace}
        '';
        clusterUrl = "https://${value.lib.vpn.ip}:6443";
        command = pkgs.writeScript "patch-downstream-kubeconfig" ''
          set -e
          VALUE=$(echo "$SSH_ORIGINAL_COMMAND" | ${pkgs.yq-go}/bin/yq e '.clusters[0].cluster.server = "${clusterUrl}"' - | base64 -w0)
          cat ${resource} | ${pkgs.yq-go}/bin/yq e '.data.value = "'"$VALUE"'"' | ${pkgs.kubectl}/bin/kubectl apply -f -
        '';
      in ''command="${command}" ${value.settings.sshPublicKey}'')
      downstreamMachines;
    };
    users.groups.${fleet.connectionUser} = {};
  };
}
