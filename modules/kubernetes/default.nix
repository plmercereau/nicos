{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.settings.kubernetes;
in {
  imports = [./vpn.nix];

  options.settings.kubernetes = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Run a k3s Kubernetes node on the machine.";
    };
    group = mkOption {
      type = types.str;
      default = "k8s-admin";
      description = "Group that has access to the k3s config and data.";
    };
  };

  config = mkMerge [
    {
      lib.kubernetes = {
        # Set of machines with k8s enabled and vpn enabled
        hosts = filterAttrs (_: cfg: cfg.settings.kubernetes.enable) config.lib.vpn.clients;
      };
    }

    (
      mkIf cfg.enable {
        networking.firewall = {
          allowedTCPPorts = [
            # 6443 # k3s: required so that pods can reach the API server (running on port 6443 by default)
            # 2379 # k3s, etcd clients: required if using a "High Availability Embedded etcd" configuration
            # 2380 # k3s, etcd peers: required if using a "High Availability Embedded etcd" configuration
            # TODO custom exposition (lan, public, vpn...)
            # TODO test without it - k3s should be able to manage its own firewall
            # 80
            # 443
          ];
          allowedUDPPorts = [
            # 8472 # k3s, flannel: required if using multi-node for inter-node networking
          ];
        };

        users.groups.${cfg.group} = {};

        services.k3s = {
          enable = true;
          role = "server";
          extraFlags = toString ([
              # * Allow group to access the k3s.yaml config
              "--write-kubeconfig-mode=640"
              # We don't disable ServiceLB so it serves on the host network, while Kube-VIP serves on the VPN
              # "--disable=servicelb"
            ]
            # Use systemd-resolved resolv.conf if resolved is enabled. See: https://github.com/k3s-io/k3s/issues/4087
            ++ optional config.services.resolved.enable "--resolv-conf=/run/systemd/resolve/resolv.conf");
        };
        # * See: https://github.com/NixOS/nixpkgs/issues/98090
        systemd.services.k3s.serviceConfig.KillMode = mkForce "mixed";

        # Packages that should always be available for manual intervention
        environment.systemPackages = with pkgs; [k3s k3s-ca-certs];

        environment.sessionVariables = {
          KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
        };

        system.activationScripts.kubernetes.text = ''
          if [[ -e /var/lib/rancher/k3s/server/tls/server-ca.crt ]]; then
            echo "K3s CA already exists, skipping generation"
          else
            # * Generate the CA certificates manually so they can be used by other services on activation e.g. fleet
            ${pkgs.k3s-ca-certs}/bin/k3s-ca-certs
          fi
          # make sure the k3s.yaml file exists and is owned by the right group
          mkdir -p /etc/rancher/k3s
          touch /etc/rancher/k3s/k3s.yaml
          chgrp ${cfg.group} /etc/rancher/k3s/k3s.yaml
        '';
      }
    )
  ];
}
