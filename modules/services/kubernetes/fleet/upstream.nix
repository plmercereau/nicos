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
  config = mkIf (k8s.enable && fleet.enable && isUpstream) {
    # TODO assertion: only one active upstream machine in the cluster

    networking.firewall = {
      allowedTCPPorts =
        [
          6443 # downstream servers should reach the upstream k3s API
        ]
        # downstream servers should connect to upstream through ssh in order to register
        ++ config.services.openssh.ports;
    };

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
            cat <<'EOF' > $out/${name}.yaml
            kind: Cluster
            apiVersion: fleet.cattle.io/v1alpha1
            metadata:
              name: ${hostName}
              namespace: ${fleet.clustersNamespace}
              labels: ${strings.toJSON labels}
            spec:
              templateValues: ${strings.toJSON values}
            EOF
          '')
          ''
            mkdir -p $out
          ''
          downstreamMachines);
      paths = ["."];
      targets = [{clusterName = "local";}];
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
          helmConfig = pkgs.writeText "fleet-config.yaml" ''
            apiVersion: helm.cattle.io/v1
            kind: HelmChartConfig
            metadata:
              name: fleet
              namespace: kube-system
            spec:
              valuesContent: ref+envsubst://$VALUES
          '';
          values = pkgs.writeText "values.yaml" ''
            apiServerURL: https://${config.lib.vpn.ip}:6443
            apiServerCA: ref+envsubst://$CA_DATA
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
            export CA_DATA=$(echo "$CONFIG" | ${pkgs.jq}/bin/jq -r '.clusters[].cluster["certificate-authority-data"]' | base64 -d)
            export VALUES=$(${pkgs.vals}/bin/vals eval -f ${values})
            ${pkgs.vals}/bin/vals eval -f ${helmConfig} > /var/lib/rancher/k3s/server/manifests/fleet-config.yaml
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
        ns = fleet.clustersNamespace;
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
          ${pkgs.kubectl}/bin/kubectl --namespace=${ns} get secret ${name}-token -o 'jsonpath={.data.values}' | base64 --decode
          echo -n "clientID: "
          ${pkgs.kubectl}/bin/kubectl --namespace=${ns} get cluster ${name} -o 'jsonpath={.spec.clientID}'
        '';
      in ''command="${command}" ${value.settings.sshPublicKey}'')
      downstreamMachines;
    };
    users.groups.${fleet.connectionUser} = {};
  };
}
