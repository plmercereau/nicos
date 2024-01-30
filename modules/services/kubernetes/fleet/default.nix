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
  '';

  chartConfig = pkgs.writeText "chart-config.yaml" ''
    apiVersion: helm.cattle.io/v1
    kind: HelmChartConfig
    metadata:
      name: fleet
      namespace: kube-system
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
      ln -sf ${chart} ${dest}/fleet.yaml
      ${
        optionalString isUpstream
        ''
          CA=$(cat /var/lib/rancher/k3s/server/tls/client-ca.pem | ${pkgs.gnused}/bin/sed 's/^/  /')
          VALUES="apiServerURL: https://${config.lib.vpn.ip}:6443
          apiServerCA: |-
          $CA"
          VALUES="$VALUES" ${pkgs.yq-go}/bin/yq e '.spec.valuesContent = strenv(VALUES) | .spec.valuesContent style="literal"' ${chartConfig} > ${dest}/fleet-config.yaml
        ''
      }
    '';
  };
}
