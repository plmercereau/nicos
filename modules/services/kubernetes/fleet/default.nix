{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  k8s = config.settings.services.kubernetes;
  cfg = k8s.fleet;
in {
  imports = [./manager.nix];
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
    # TODO move to ./agent.nix
    agent = {
      enable = mkOption {
        type = types.bool;
        default = cfg.enable;
        description = "Enable fleet agent";
      };
    };
  };

  # TODO connect manager and agents
  # * See: https://fleet.rancher.io/installation
  config = mkIf (k8s.enable && cfg.enable) {
    environment.etc."nicos/fleet.yaml".text = ''
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
        repo: https://rancher.github.io/fleet-helm-charts/
        chart: fleet-crd
        targetNamespace: ${cfg.namespace}
      ---
      apiVersion: helm.cattle.io/v1
      kind: HelmChart
      metadata:
        name: fleet
        namespace: kube-system
      spec:
        repo: https://rancher.github.io/fleet-helm-charts/
        chart: fleet
        targetNamespace: ${cfg.namespace}
    '';
    system.activationScripts = {
      # * Install fleet from the helm chart using the k3s manifests
      fleetService = ''
        ln -sf /etc/nicos/fleet.yaml /var/lib/rancher/k3s/server/manifests/fleet.yaml
      '';
    };
  };
}
