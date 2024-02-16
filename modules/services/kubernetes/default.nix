{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.settings.services.kubernetes;
in {
  imports = [./fleet ./vpn];

  options.settings.services.kubernetes = {
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
      extraFlags = toString ([
          # * Allow group to access the k3s.yaml config
          "--write-kubeconfig-mode=640"
          "--disable=servicelb"
        ]
        # Use systemd-resolved resolv.conf if resolved is enabled. See: https://github.com/k3s-io/k3s/issues/4087
        ++ optional config.services.resolved.enable "--resolv-conf=/run/systemd/resolve/resolv.conf");
    };

    environment.systemPackages = [pkgs.k3s];

    environment.sessionVariables = {
      KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
    };

    system.activationScripts.kubernetes.text = let
      # not very elegant - would be nicer to access through pkgs.k3s-ca-certs instead
      generateCA = import ../../../packages/k3s-ca-certs.nix pkgs;
      manifests = "/var/lib/rancher/k3s/server/manifests";
      vip = "10.100.0.10";
      traefik = pkgs.writeText "traefik-config.yaml" ''
        apiVersion: helm.cattle.io/v1
        kind: HelmChartConfig
        metadata:
          name: traefik
          namespace: kube-system
        spec:
          valuesContent: |-
            service:
              externalIPs:
                - ${vip}
                #- 10.136.1.11
                #- 10.100.0.6

      '';
      metalLB = pkgs.writeText "metallb.yaml" ''
        apiVersion: helm.cattle.io/v1
        kind: HelmChart
        metadata:
          name: metallb
          namespace: kube-system
        spec:
          repo: https://metallb.github.io/metallb
          chart: metallb
          version: 0.14.3
          targetNamespace: kube-system
        ---
        apiVersion: metallb.io/v1beta1
        kind: IPAddressPool
        metadata:
          name: local
          namespace: kube-system
        spec:
          addresses:
            - 10.136.1.11/32
        ---
        apiVersion: metallb.io/v1beta1
        kind: IPAddressPool
        metadata:
          name: wg
          namespace: kube-system
        spec:
          addresses:
            - 10.100.0.6/32
      '';
      kubeVip = pkgs.writeText "kube-vip.yaml" ''
        apiVersion: v1
        kind: ServiceAccount
        metadata:
          name: kube-vip
          namespace: kube-system
        ---
        apiVersion: rbac.authorization.k8s.io/v1
        kind: ClusterRole
        metadata:
          annotations:
            rbac.authorization.kubernetes.io/autoupdate: "true"
          name: system:kube-vip-role
        rules:
          - apiGroups: [""]
            resources: ["secrets"]
            resourceNames: ["wireguard"]
            verbs: ["get", "watch", "list"]
          - apiGroups: [""]
            resources: ["services/status"]
            verbs: ["update"]
          - apiGroups: [""]
            resources: ["services", "endpoints"]
            verbs: ["list","get","watch", "update"]
          - apiGroups: [""]
            resources: ["nodes"]
            verbs: ["list","get","watch", "update", "patch"]
          - apiGroups: ["coordination.k8s.io"]
            resources: ["leases"]
            verbs: ["list", "get", "watch", "update", "create"]
          - apiGroups: ["discovery.k8s.io"]
            resources: ["endpointslices"]
            verbs: ["list","get","watch", "update"]
        ---
        kind: ClusterRoleBinding
        apiVersion: rbac.authorization.k8s.io/v1
        metadata:
          name: system:kube-vip-binding
        roleRef:
          apiGroup: rbac.authorization.k8s.io
          kind: ClusterRole
          name: system:kube-vip-role
        subjects:
        - kind: ServiceAccount
          name: kube-vip
          namespace: kube-system
        # ---
        # apiVersion: v1
        # kind: ConfigMap
        # metadata:
        #   name: kubevip
        #   namespace: kube-system
        # data:
        #   cidr-default: 10.136.0.0/16                         # CIDR-based IP range for use in the default Namespace
        #   #range-development: 192.168.0.210-192.168.0.219      # Range-based IP range for use in the development Namespace
        #   #cidr-finance: 192.168.0.220/29,192.168.0.230/29     # Multiple CIDR-based ranges for use in the finance Namespace
        #   cidr-global: 10.136.0.0/16                       # CIDR-based range which can be used in any Namespace
        #   # range-global: 1.1.1.1-10.200.0.0
        ---
        apiVersion: apps/v1
        kind: DaemonSet
        metadata:
          creationTimestamp: null
          labels:
            app.kubernetes.io/name: kube-vip-ds
            app.kubernetes.io/version: v0.7.0
          name: kube-vip-ds
          namespace: kube-system
        spec:
          selector:
            matchLabels:
              app.kubernetes.io/name: kube-vip-ds
          template:
            metadata:
              creationTimestamp: null
              labels:
                app.kubernetes.io/name: kube-vip-ds
                app.kubernetes.io/version: v0.7.0
            spec:
              affinity:
                nodeAffinity:
                  requiredDuringSchedulingIgnoredDuringExecution:
                    nodeSelectorTerms:
                    - matchExpressions:
                      - key: node-role.kubernetes.io/master
                        operator: Exists
                    - matchExpressions:
                      - key: node-role.kubernetes.io/control-plane
                        operator: Exists
              containers:
              - args:
                - manager
                image: ghcr.io/kube-vip/kube-vip:v0.7.0
                imagePullPolicy: Always
                name: kube-vip
                env:
                - name: vip_loglevel
                  value: "5"
                - name: address
                  value: ${vip}
                - name: vip_interface
                  value: "wlo1" # overriden by wg0 in wireguard mode?
                - name: vip_wireguard
                  value: "true"
                # - name: vip_ddns
                #   value: "true"

                - name: vip_servicesinterface
                  value: "wlo1"

                - name: lb_fwdmethod
                  value: "nat"
                # - name: enable_node_labeling
                #   value: "true"
                - name: prometheus_server
                  value: :2112
                #- name: vip_arp # TODO disable when using wireguard
                #  value: "true"
                - name: port
                  value: "6443"
                - name: vip_cidr
                  value: "16"
                - name: dns_mode
                  value: first
                - name: cp_enable
                  value: "true"
                - name: cp_namespace
                  value: kube-system
                - name: svc_enable
                  value: "true"
                - name: svc_leasename
                  value: plndr-svcs-lock
                - name: svc_election
                  value: "true"
                - name: vip_leaderelection
                  value: "true"
                - name: vip_leasename
                  value: plndr-cp-lock
                - name: vip_leaseduration
                  value: "5"
                - name: vip_renewdeadline
                  value: "3"
                - name: vip_retryperiod
                  value: "1"
                resources: {}
                securityContext:
                  capabilities:
                    add:
                    - NET_ADMIN
                    - NET_RAW
              hostNetwork: true
              serviceAccountName: kube-vip
              tolerations:
              - effect: NoSchedule
                operator: Exists
              - effect: NoExecute
                operator: Exists
          updateStrategy: {}
        status:
          currentNumberScheduled: 0
          desiredNumberScheduled: 0
          numberMisscheduled: 0
          numberReady: 0

      '';
      # OE3AWnBnkZG9BVhb+RFy7sgeKvmnNBNSG+wkdHKMyXw=
    in ''
      if [[ -e /var/lib/rancher/k3s/server/tls/server-ca.crt ]]; then
        echo "K3s CA already exists, skipping generation"
      else
        # * Generate the CA certificates manually so they can be used by other services on activation e.g. fleet
        ${generateCA}/bin/k3s-ca-certs
      fi
      # make sure the k3s.yaml file exists and is owned by the right group
      mkdir -p /etc/rancher/k3s
      touch /etc/rancher/k3s/k3s.yaml
      chgrp ${cfg.group} /etc/rancher/k3s/k3s.yaml
      mkdir -p ${manifests}
      ln -sf ${traefik} ${manifests}/traefik-config.yaml
      # ln -sf ${metalLB} ${manifests}/metallb.yaml
      ln -sf ${kubeVip} ${manifests}/kube-vip.yaml
    '';
  };
}
