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
  downstreamClusters = pkgs.writeText "downstream-clusters.yaml" (concatMapStringsSep "---" (ds: ''
    kind: Cluster
    apiVersion: fleet.cattle.io/v1alpha1
    metadata:
      name: ${ds.networking.hostName}
      namespace: clusters
    spec:
      kubeConfigSecret: ${ds.networking.hostName}-kubeconfig
    ---
    kind: Secret
    apiVersion: v1
    metadata:
      name:  ${ds.networking.hostName}-kubeconfig
      namespace: clusters
    data:
      value: ""
      apiServerURL: "https://${ds.networking.hostName}.${config.settings.networking.vpn.domain}:6443"
  '') (attrValues downstreamMachines));
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
  # TODO assertion: only one active upstream machine in the cluster
  config = mkIf (k8s.enable && cfg.enable && isUpstream) {
    lib.fleet.patchKubeConfigDrvs = mapAttrs (name: value:
      pkgs.writeScript "patch-downstream-kubeconfig" ''
        ${pkgs.kubectl}/bin/kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml patch secret ${name}-kubeconfig --type=json -p='[{"op": "replace", "path": "/data/value", "value": "$1"}]'
      '')
    downstreamMachines;

    users.users.${cfg.connectionUser} = {
      isSystemUser = true;
      group = cfg.connectionUser;
      extraGroups = ["wheel"]; # TODO allowed to access to /etc/rancher/k3s/k3s.yaml -> dedicated kubernetes-admin group?
      openssh.authorizedKeys.keys =
        mapAttrsToList (name: value: ''command="${config.lib.fleet.patchKubeConfigDrvs.${name}}" ${value.settings.sshPublicKey}'')
        downstreamMachines;
    };
    users.groups.${cfg.connectionUser} = {};

    # TODO Add the clusters to the git-repo on the local-cluster namespace!!!
    system.activationScripts.kubernetes-fleet-upstream.text = let
      dest = "/var/lib/rancher/k3s/server/manifests";
      apiServerURL = "https://${config.networking.hostName}.${config.settings.networking.vpn.domain}:6443";
    in ''
      mkdir -p ${dest}
      ln -sf ${downstreamClusters} ${dest}/fleet-clusters.yaml
    '';
  };
}
