{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.settings.services.kubernetes;
in {
  imports = [./fleet];

  options.settings.services.kubernetes = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Run a k3s Kubernetes node on the machine.";
    };
    group = mkOption {
      type = types.str;
      default = "k8s-admin";
      description = "Group that has access to the k3s config.";
    };
  };

  config = mkIf cfg.enable {
    networking.firewall = {
      allowedTCPPorts = [
        # 6443 # k3s: required so that pods can reach the API server (running on port 6443 by default)
        # 2379 # k3s, etcd clients: required if using a "High Availability Embedded etcd" configuration
        # 2380 # k3s, etcd peers: required if using a "High Availability Embedded etcd" configuration
        # TODO custom exposition (lan, public, vpn...)
        80
        443
      ];
      allowedUDPPorts = [
        # 8472 # k3s, flannel: required if using multi-node for inter-node networking
      ];
    };

    users.groups.${cfg.group} = {};

    services.k3s = {
      enable = true;
      role = "server";
      extraFlags = toString [
        # * Allow group to access the k3s.yaml config
        "--write-kubeconfig-mode=640"
      ];
    };

    environment.systemPackages = [pkgs.k3s];

    environment.sessionVariables = {
      KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
    };

    system.activationScripts.kubernetes.text = let
      # not very elegant - would be nicer to access through pkgs.k3s-ca-certs instead
      generateCA = import ../../../packages/k3s-ca-certs.nix pkgs;
    in ''
      if [[ -e /var/lib/rancher/k3s/server/tls/server-ca.crt ]]; then
        echo "K3s CA already exists, skipping generation"
      else
        # * Generate the CA certificates manually so they can be used by other services on activation e.g. fleet
        ${generateCA}/bin/k3s-ca-certs
      fi
      if [[ -e /var/lib/rancher/k3s ]]; then
        chgrp -R ${cfg.group} /var/lib/rancher/k3s
      fi
      # * Allow group users to access the k3s config
      # Create an empty file if it doesn't exist yet, in order to make sure the group is the right one
      mkdir -p /etc/rancher/k3s
      touch /etc/rancher/k3s/k3s.yaml
      chgrp ${cfg.group} /etc/rancher/k3s/k3s.yaml
    '';
  };
}
