{
  config,
  lib,
  pkgs,
  cluster,
  ...
}:
with lib; let
  /*
  TODO

  1. on upstream
    - create a dedicated user
    - each upstream can connect to ssh with their machine ssh key
    - they can then only run one command: set the kubeconfig in the secret
  2. on downstream (roughly)
    - set a systemd service that will only run once (not on every boot, only once for all the life of the machine)
    - the service checks if fleet is already configured
    - if not, set the kubeconfig through the upstream
    - make sure we loop/wait until everything is ok
  */
  k8s = config.settings.services.kubernetes;
  cfg = k8s.fleet;

  isStandalone = cfg.mode == "standalone";
  isUpstream = cfg.mode == "upstream";

  chart = pkgs.writeText "chart.yaml" ''
    apiVersion: v1
    kind: Namespace
    metadata:
      name: ${cfg.clustersNamespace}
    ---
    apiVersion: v1
    kind: Namespace
    metadata:
      name: ${cfg.namespace}
    ---
    apiVersion: helm.cattle.io/v1
    kind: HelmChart
    metadata:
      name: fleet-crd
      namespace: kube-system
    spec:
      repo: https://rancher.github.io/fleet-helm-charts
      chart: fleet-crd
      targetNamespace: ${cfg.namespace}
    ---
    apiVersion: helm.cattle.io/v1
    kind: HelmChart
    metadata:
      name: fleet
      namespace: kube-system
    spec:
      repo: https://rancher.github.io/fleet-helm-charts
      chart: fleet
      targetNamespace: ${cfg.namespace}
      ${optionalString isUpstream ''
      valuesContent: |-
        apiServerURL: "https://${config.networking.hostName}.${config.settings.networking.vpn.domain}:6443"
        apiServerCA: "ref+file:///var/lib/rancher/k3s/server/tls/root-ca.pem"
    ''}
  '';
in {
  imports = [./git-repo.nix ./upstream.nix ./downstream.nix];
  options.settings.services.kubernetes.fleet = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable fleet";
    };
    namespace = mkOption {
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
  };

  config = mkIf (k8s.enable && cfg.enable && (isStandalone || isUpstream)) {
    # TODO assertion: fleet upstream/downstream system only works with VPN
    system.activationScripts.kubernetes-fleet.text = let
      dest = "/var/lib/rancher/k3s/server/manifests";
    in ''
      mkdir -p ${dest}
      cat ${chart} | ${pkgs.vals}/bin/vals eval > ${dest}/fleet.yaml
    '';
  };
}
