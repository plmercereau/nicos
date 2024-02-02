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
  isUpstream = cfg.mode == "upstream";

  downstreamMachines = filterAttrs (name: h: h.nixpkgs.hostPlatform.isLinux && h.settings.services.kubernetes.fleet.mode == "downstream") cluster.hosts;
  downstreamClusters = pkgs.concatText "downstream-clusters.jsonl" (mapAttrsToList (name: value:
    pkgs.writeText "${name}.json" (strings.toJSON {
      kind = "Cluster";
      apiVersion = "fleet.cattle.io/v1alpha1";
      metadata = {
        inherit name;
        namespace = cfg.clustersNamespace;
      };
      inherit (value.settings.services.kubernetes.fleet) labels;
      spec = {
        kubeConfigSecret = "${name}-kubeconfig";
      };
    }))
  downstreamMachines);
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

  config = mkIf (k8s.enable && cfg.enable && isUpstream) {
    # TODO assertion: only one active upstream machine in the cluster
    users.users.${cfg.connectionUser} = {
      isSystemUser = true;
      shell = pkgs.bash;
      group = cfg.connectionUser;
      extraGroups = [k8s.group];
      openssh.authorizedKeys.keys = mapAttrsToList (name: value: let
        resource = pkgs.writeText "" ''
          kind: Secret
          apiVersion: v1
          metadata:
            name:  ${name}-kubeconfig
            namespace: ${cfg.clustersNamespace}
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
    users.groups.${cfg.connectionUser} = {};

    # TODO Add the clusters to the git-repo on the local-cluster namespace instead of using the k3s addon manifests
    system.activationScripts.kubernetes-fleet-upstream.text = let
      dest = "/var/lib/rancher/k3s/server/manifests";
    in ''
      mkdir -p ${dest}
      ${pkgs.yq-go}/bin/yq -p=json ${downstreamClusters} > ${dest}/fleet-clusters.yaml
    '';
  };
}
