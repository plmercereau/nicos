{
  config,
  lib,
  pkgs,
  cluster,
  ...
}:
with lib; let
  inherit (config.settings) kubernetes tailnet;
  cfg = config.settings.rancher;
in {
  options.settings.rancher = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "This Cluster is the Rancher Manager";
    };
  };

  config = mkIf (cfg.enable) {
    # TODO there should be only one Rancher manager
    assertions = [
      {
        assertion = kubernetes.enable;
        message = "Rancher requires Kubernetes to be enabled.";
      }
    ];

    # * Install the Fleet Manager and CRD as a k3s manifest if Fleet runs on upstream mode
    system.activationScripts = {
      kubernetes-rancher.text = let
        values = pkgs.writeText "values.json" (strings.toJSON chartValues);
        chartValues = {
          replicas = 1;
          bootstrapPassword = "admin";
          hostname = "10.136.1.11.sslip.io";
          # certmanager.version = "v1.14.3";
          # * Tailscale Ingress
          # hostname = "rancher-${kubernetes.name}";
          # tls = "external";
          # ingress.enabled = false;
          # ingress.ingressClassName = "tailscale";
        };
        ingress = pkgs.writeText "ingress.yaml" ''
          apiVersion: networking.k8s.io/v1
          kind: Ingress
          metadata:
            name: rancher
            namespace: cattle-system
          spec:
            ingressClassName: tailscale
            rules:
            - http:
                paths:
                - backend:
                    service:
                      name: rancher
                      port:
                        number: 80
                  path: /
                  pathType: Prefix
            tls:
              - hosts:
                - "rancher-${config.networking.hostName}"
        '';
      in ''
        ${pkgs.k3s-chart {
          name = "rancher";
          namespace = "cattle-system";
          repo = "https://releases.rancher.com/server-charts/latest";
          chart = "rancher";
          version = "2.8.3";
        }}
        ${pkgs.k3s-chart-config "rancher"} "$(${pkgs.vals}/bin/vals eval -f ${values})"
        # TODO extension operator
        # TODO install elemental UI
        ${pkgs.k3s-chart {
          name = "elemental-operator";
          namespace = "cattle-elemental-system";
          # * Stable
          chart = "oci://registry.suse.com/rancher/elemental-operator-chart";
          # * Development (ARM)
          # chart = "oci://registry.opensuse.org/isv/rancher/elemental/dev/charts/rancher/elemental-operator-chart";
          # * Staging
          # chart = "oci://registry.opensuse.org/isv/rancher/elemental/staging/charts/rancher/elemental-operator-chart"; # * not great, no pinned version
          # chart = "elemental-operator";
          # version = "1.5.0";
          # values = {
          #   image.repository = "registry.suse.com/rancher/elemental-teal-channel";
          #   image.tag = "1.4.2"; # * staging
          # };
        }}
        ${pkgs.k3s-chart {
          name = "elemental-operator-crds";
          namespace = "cattle-elemental-system";
          # * Stable
          chart = "oci://registry.suse.com/rancher/elemental-operator-crds-chart";
          # * Development (ARM)
          # chart = "oci://registry.opensuse.org/isv/rancher/elemental/dev/charts/rancher/elemental-operator-crds-chart";
          # * Staging
          # chart = "oci://registry.opensuse.org/isv/rancher/elemental/staging/charts/rancher/elemental-operator-crds-chart"; # * not great, no pinned version
          # chart = "elemental-operator";
          # version = "1.5.0";
        }}
        # TODO reuse tailscale ingress
        # ln -sf ${ingress} /var/lib/rancher/k3s/server/manifests/rancher-ingress.yaml
      '';
    };

    # * Update the fleet helm values in the k3s manifests after the k3s service is up, so it gets the correct CA certificate
    systemd.services.rancher-config = {
      wantedBy = ["multi-user.target"];
      after = ["k3s.service"];
      wants = ["k3s.service"];
      description = "update the Rancher Manager config";
      environment = {
        KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = let
        in
          pkgs.writeShellScript "set-rancher-config" ''
            # TODO create a derivation instead of using kubectl apply -f https://
            ${pkgs.kubectl}/bin/kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.3/cert-manager.crds.yaml
          '';
        Restart = "on-failure";
        RestartSec = 3;
        RemainAfterExit = "no";
      };
    };

    # downstream servers should be able to reach the upstream k3s API to register to the fleet
    networking.firewall.allowedTCPPorts = [6443];
  };
}
