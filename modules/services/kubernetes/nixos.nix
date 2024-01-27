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
  };

  config = mkIf cfg.enable {
    networking.firewall = {
      allowedTCPPorts = [
        6443 # k3s: required so that pods can reach the API server (running on port 6443 by default)
        # 2379 # k3s, etcd clients: required if using a "High Availability Embedded etcd" configuration
        # 2380 # k3s, etcd peers: required if using a "High Availability Embedded etcd" configuration
        80 # TODO custom exposition (lan, public, vpn...)
        443 # TODO idem2
      ];
      allowedUDPPorts = [
        # 8472 # k3s, flannel: required if using multi-node for inter-node networking
      ];
    };

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

    system.activationScripts.kubernetes = ''
      # * Allow wheel users to access the k3s config
      chgrp wheel /etc/rancher/k3s/k3s.yaml
      # TODO chown wheel the /var/lib/rancher/... too?
    '';
  };
}
