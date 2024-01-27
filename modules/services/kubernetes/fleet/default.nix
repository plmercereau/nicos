{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  /*
  TODO

  # CLI
  - [ ] fetch the upstream cluster root CA and store in in the right secret
  */
  k8s = config.settings.services.kubernetes;
  cfg = k8s.fleet;
  isDownstreamCluster = cfg.mode == "downstream";

  namespaceManifest = pkgs.writeText "namespace.yaml" ''
    apiVersion: v1
    kind: Namespace
    metadata:
      name: ${cfg.namespace}
  '';

  fleetManifest = let
    src = pkgs.fetchurl {
      url = "https://github.com/rancher/fleet-helm-charts/releases/download/fleet-0.9.0/fleet-0.9.0.tgz";
      hash = "";
    };
  in
    pkgs.runCommand "" {} ''
      mkdir $out
      ${pkgs.kubernetes-helm}/bin/helm template -n ${cfg.namespace} ${src}
    '';

  fleetCrdManifest = let
    src = fetchurl {
      url = "https://github.com/rancher/fleet-helm-charts/releases/download/fleet-crd-0.9.0/fleet-crd-0.9.0.tgz";
      hash = "";
    };
  in
    pkgs.runCommand "" {} ''
      mkdir $out
      ${pkgs.kubernetes-helm}/bin/helm template -n ${cfg.namespace} ${src} ${optionalString isDownstreamCluster ''--set apiServerURL="${cfg.apiServerURL}" --set apiServerCA="ref+file://${cfg.apiServerCAPath}"''}
    '';
in {
  imports = [./git-repo.nix];
  options.settings.services.kubernetes.fleet = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable fleet";
    };
    namespace = mkOption {
      type = types.str;
      default = "fleet-system";
      description = "Fleet namespace";
    };
    mode = mkOption {
      type = types.enum ["standalone" "upstream" "downstream"];
      default = "standalone";
      # TODO assertion: only one active upstream machine in the cluster
      # TODO assertion: an active upstream machine exists if the machine is downstream
      description = ''
        Fleet mode.
        Standalone will install the manager and agent on the same node, and will manage its own applications.
        Upstream will install the manager, and will manage applications on downstream clusters. There should be only one upstream cluster in the project.
        Downstream will install the agent, and will manage applications on the upstream cluster. An upstream cluster is required in the project.
      '';
    };
    apiServerCAPath = mkOption {
      type = types.nullOr types.str;
      default = null;
      # TODO assertion: should be set when mode == "downstream"
      description = ''
        Path to the CA certificate file of the upstream cluster. The file should be a valid PEM file.

        A value is required when the mode is set to downstream.
      '';
    };
    apiServerURL = mkOption {
      type = types.nullOr types.str;
      default = null;
      # TODO assetion: should be set when mode == "downstream"
      # TODO set the path to the upstream cluster
      description = ''
        URL of the upstream cluster.
          
        A value is required when the mode is set to downstream.'';
    };
  };

  # * See: https://fleet.rancher.io/installation
  config = mkIf (k8s.enable && cfg.enable) {
    system.activationScripts = {
      # * Install fleet from the helm chart using the k3s manifests
      fleetService = let
        dest = "/var/lib/rancher/k3s/server/manifests";
      in ''
        ln -sf ${namespaceManifest} ${dest}/fleet-namespace.yaml
        ln -sf ${fleetCrdManifest} ${dest}/fleet-crd.yaml
        ${pkgs.vals}/bin/vals eval ${fleetManifest} > ${dest}/fleet.yaml
      '';
    };
  };
}
