{
  config,
  lib,
  pkgs,
  cluster,
  ...
}:
with lib; let
  k8s = config.settings.services.kubernetes;
  cfg = k8s.vpn;
  hostVpn = config.settings.networking.vpn;
  # Set of machines with k8s enabled and k8s vpn enabled
  k8sHosts =
    filterAttrs
    (_: cfg: cfg.settings.services.kubernetes.enable && cfg.settings.services.kubernetes.vpn.enable)
    cluster.hosts;

  inherit (config.lib.vpn) machineIp bastion;
  inherit (bastion.settings.services.kubernetes.vpn) cidr domain;
  inherit (bastion.settings.networking.vpn.bastion) extraPeers;
  vip = machineIp cidr hostVpn.id;
in {
  options.settings.services.kubernetes.vpn = {
    enable = mkOption {
      description = ''
        Enable access to the cluster through Wireguard.
      '';
      type = types.bool;
      default = false;
    };
    cidr = mkOption {
      # TODO check for conflicts
      # TODO should only be defined in the bastion
      description = ''
        CIDR that defines the VPN network of the Kubernetes cluster.
      '';
      type = types.str;
      default = "10.101.0.0/24";
    };
    domain = mkOption {
      # TODO should only be defined in the bastion
      description = ''
        Domain name of the clusters.

        The clusters will then be accessible through `hostname.domain`.
      '';
      type = types.str;
      default = "cluster";
    };

    privateKeyFile = mkOption {
      # TODO populate privateKeyFile with agenix
      # TODO check for a valid private key + not null if vpn is enabled
      description = ''
        Path to the private key file of the machine.

        This value is required when the VPN is enabled on the Kubernetes cluster.
      '';
      type = types.nullOr types.str;
      default = null;
    };

    publicKey = mkOption {
      # TODO check for a valid public key + not null if vpn is enabled
      description = ''
        Wireguard public key of the machine.

        This value is required when the VPN is enabled on the Kubernetes cluster.
      '';
      type = types.nullOr types.str;
      default = null;
    };
  };

  config = {
    settings.networking.vpn.peers = mkIf hostVpn.bastion.enable (
      mapAttrs' (_: machine: nameValuePair machine.publicKey ["${machineIp cfg.cidr machine.id}/32"])
      ( # Add the list of the client machines configured in the cluster of machines
        (
          mapAttrs (_: machine: {
            inherit (machine.settings.services.kubernetes.vpn) publicKey;
            inherit (machine.settings.networking.vpn) id;
          })
          k8sHosts
        )
        // hostVpn.bastion.extraPeers # Also allow an IP for the extra peers
      )
    );

    networking = mkIf hostVpn.bastion.enable {
      # * We add the list of the hosts with their VPN IP and name.vpn-domain to /etc/hosts so dnsmasq can resolve them.
      hosts =
        lib.mapAttrs' (name: machine: lib.nameValuePair (machineIp cidr machine.settings.networking.vpn.id) ["${name}.${domain}"])
        k8sHosts;

      wg-quick.interfaces.${hostVpn.interface} = {
        # Add the k8s vpn address to the bastion
        address = [
          "${machineIp cidr hostVpn.id}/${toString (config.lib.network.ipv4.cidrToBitMask cidr)}"
        ];
      };
    };

    system.activationScripts = mkIf (k8s.enable && cfg.enable) {
      kubernetes-vpn.text = let
        manifests = "/var/lib/rancher/k3s/server/manifests";
        # TODO do we really need this?
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
        '';
        kubeVip = pkgs.stdenv.mkDerivation {
          name = "kube-vip-chart";
          meta.description = "bundle the kube-vip helm chart into a HelmChart resource";
          src = ./kube-vip;
          buildPhase = let
            manifest = pkgs.writeText "kube-vip.yaml" ''
              apiVersion: helm.cattle.io/v1
              kind: HelmChart
              metadata:
                name: kube-vip
                namespace: kube-system
              spec:
                targetNamespace: kube-system
                chartContent: ref+envsubst://$CHART
                bootstrap: true
            '';
          in ''
            ls
            ${pkgs.kubernetes-helm}/bin/helm package .
            export CHART=$(cat kube-vip-*.tgz | base64)
            ${pkgs.vals}/bin/vals eval -f ${manifest} > chart.yaml
          '';

          installPhase = ''
            cp chart.yaml $out
          '';
        };
      in ''
        mkdir -p ${manifests}
        ln -sf ${traefik} ${manifests}/traefik-config.yaml
        ln -sf ${kubeVip} ${manifests}/kube-vip.yaml
      '';
    };

    # * Update the fleet helm values in the k3s manifests after the k3s service is up, so it gets the correct CA certificate
    systemd.services.kube-vip = mkIf (k8s.enable && cfg.enable) {
      wantedBy = ["multi-user.target"];
      after = ["k3s.service"];
      wants = ["k3s.service"];
      description = "update the kube-vip secret and manifest after k3s is up";
      environment = {
        KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = let
          secret = pkgs.writeText "kube-vip-secret.yaml" ''
            apiVersion: v1
            kind: Secret
            metadata:
              name: wireguard
              namespace: kube-system
            type: Opaque
            data:
              peerEndpoint: ref+envsubst://$SERVER_IP
              peerPublicKey: ref+envsubst://$SERVER_PUBLIC_KEY
              privateKey: ref+envsubst://$PRIVATE_KEY
          '';
        in
          pkgs.writeShellScript "set-fleet-config" ''
            while true; do
              if "$(${pkgs.kubectl}/bin/kubectl config view -o json --raw)" | ${pkgs.jq}/bin/jq '.clusters | length' | grep -q '^0$'; then
                echo "Error: No clusters found in kubeconfig. Assuming the cluster is not ready yet. Retrying in 1 second..."
                sleep 1
              else
                break
              fi
            done
            export SERVER_IP=$(echo -n "${bastion.settings.networking.publicIP}" | base64)
            export SERVER_PUBLIC_KEY=$(echo -n "${bastion.settings.networking.vpn.publicKey}" | base64)
            export PRIVATE_KEY=$(cat "${cfg.privateKeyFile}" | base64)
            ${pkgs.vals}/bin/vals eval -f ${secret} | ${pkgs.kubectl}/bin/kubectl apply -f -
          '';
        Restart = "on-failure";
        RestartSec = 3;
        RemainAfterExit = "no";
      };
    };
  };
}
