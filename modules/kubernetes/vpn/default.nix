{
  config,
  lib,
  pkgs,
  cluster,
  ...
}:
with lib; let
  k8s = config.settings.services.kubernetes;
  vpn = config.settings.networking.vpn;
  hostVpn = config.settings.networking.vpn;
  inherit (config.lib.vpn) machineIp bastion clients;

  # Set of machines with k8s enabled and vpn enabled
  k8sHosts =
    filterAttrs
    (_: cfg: cfg.settings.services.kubernetes.enable)
    clients;

  inherit (bastion.settings.services.kubernetes.vpn) cidr domain;
  inherit (bastion.settings.networking.vpn.bastion) extraPeers;
  vip = machineIp cidr hostVpn.id;
in {
  # TODO should be defined in the bastion
  options.settings.services.kubernetes.vpn = {
    cidr = mkOption {
      # TODO check for conflicts with settings.networking.vpn.cidr
      description = ''
        CIDR that defines the VPN network of the Kubernetes cluster.
      '';
      type = types.str;
      default = "10.101.0.0/24";
    };
    domain = mkOption {
      # TODO check for conflicts with settings.networking.vpn.domain
      description = ''
        Domain name of the cluster.

        The clusters will then be accessible through `hostname.domain`.
      '';
      type = types.str;
      default = "cluster";
    };
  };

  config = {
    settings.networking.vpn.peers = mkIf hostVpn.bastion.enable (
      mapAttrs' (_: machine: nameValuePair machine.publicKey ["${machineIp k8s.vpn.cidr machine.id}/32"])
      ( # Add the list of the client machines configured in the cluster of machines
        (
          mapAttrs (_: machine: {
            inherit (machine.settings.networking.vpn) id publicKey;
          })
          k8sHosts
        )
        // hostVpn.bastion.extraPeers # Also allow an IP for the extra peers
      )
    );

    networking = mkIf hostVpn.bastion.enable {
      wg-quick.interfaces.${hostVpn.interface} = {
        # Add the k8s vpn address to the bastion
        address = [
          "${machineIp cidr hostVpn.id}/${toString (config.lib.network.ipv4.cidrToBitMask cidr)}"
        ];
      };
    };

    # * We add the list of the hosts with k8s enabled with vpn with their VPN IP and name.vpn-domain to /etc/hosts so dnsmasq can resolve them.
    services.dnsmasq.settings.address =
      mkIf hostVpn.bastion.enable
      (
        lib.mapAttrsToList (name: machine: "/${name}.${domain}/${machineIp cidr machine.settings.networking.vpn.id}")
        k8sHosts
      );

    system.activationScripts = mkIf (k8s.enable && vpn.enable) {
      kubernetes-vpn.text = let
        manifests = "/var/lib/rancher/k3s/server/manifests";
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
        ln -sf ${kubeVip} ${manifests}/kube-vip.yaml
      '';
    };

    # * Update the fleet helm values in the k3s manifests after the k3s service is up, so it gets the correct CA certificate
    systemd.services.kube-vip = mkIf (k8s.enable && vpn.enable) {
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
          # TODO insert the sha256sum of the secret into the kube-vip manifest (spec.template.metadata.annotations.secret-hash) so the kube-vip pods are restarted when the secret changes
          # TODO best then to include the wireguard secret to the helm values so helm takes care of the hash?
          # TODO but then, the helm chart operator should NOT store the secret in clear in the HelmChartConfig...
          # TODO another option would be to use fleet direclty.
          # TODO but then we cannot get rid of the "vpn ip" dependency
          # TODO ->>> %{KUBERNETES_API}% -> %{NODE_IP_XXX}% variable
          # TODO maybe better to review this "local git daemon":
          # A. use a remote git repo (but then how to run in dev mode?). And then "clusters" would be embedded into a HelmChart/HelmChartConfig so they can be updated/removed
          # B. run a git daemon inside the cluster with a link to the host filesystem
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
            export PRIVATE_KEY=$(cat "${config.age.secrets.vpn.path}" | base64)
            ${pkgs.vals}/bin/vals eval -f ${secret} | ${pkgs.kubectl}/bin/kubectl apply -f -
          '';
        Restart = "on-failure";
        RestartSec = 3;
        RemainAfterExit = "no";
      };
    };
  };
}
