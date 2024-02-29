{
  config,
  lib,
  pkgs,
  cluster,
  ...
}:
with lib; let
  cfg = config.settings.kubernetes;
in {
  options.settings = {
    kubernetes = {
      # TODO import from cluster.nix
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Run a k3s Kubernetes node on the machine.";
      };
      oauthClientId = mkOption {
        type = types.str;
        description = "OAuth client ID for the tailscale operator.";
      };
      clusterName = mkOption {
        type = types.str;
        default = config.networking.hostName;
        description = "Name of the k3s cluster.";
      };
      group = mkOption {
        type = types.str;
        default = "k8s-admin";
        description = "Group that has access to the k3s config and data.";
      };
    };
  };

  config = mkIf cfg.enable {
    networking.firewall = {
      allowedTCPPorts = [
        # 6443 # k3s: required so that pods can reach the API server (running on port 6443 by default)
        # 2379 # k3s, etcd clients: required if using a "High Availability Embedded etcd" configuration
        # 2380 # k3s, etcd peers: required if using a "High Availability Embedded etcd" configuration
        # TODO custom exposition (lan, public, tailscale...)
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

      ${pkgs.k3s-chart {
        name = "tailscale-operator";
        namespace = "tailscale";
        repo = "https://pkgs.tailscale.com/helmcharts";
        chart = "tailscale-operator";
        version = "1.61.11";
        values = {
          apiServerProxyConfig.mode = "true";
          operatorConfig.hostname = "cluster-${cfg.clusterName}";
        };
      }}
    '';

    systemd.services.k3s-init = let
    in {
      wantedBy = ["multi-user.target"];
      after = ["k3s.service"];
      wants = ["k3s.service"];
      description = "update the tailscale secrets";
      environment = {
        KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = pkgs.writeShellScript "set-tailscale-secrets" ''
          ${pkgs.k8s-apply-secret {
            name = "operator-oauth";
            namespace = "tailscale";
            values = {
              client_id.content = cfg.oauthClientId;
              client_secret.file = config.age.secrets.tailscale-cluster.path;
            };
            wait = true;
          }}
        '';
        Restart = "on-failure";
        RestartSec = 3;
        RemainAfterExit = "no";
      };
    };
  };
}
