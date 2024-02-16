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
  k8sHosts = filterAttrs (_: cfg: cfg.settings.services.kubernetes.enable) cluster.hosts;
  servers = filterAttrs (_: cfg: cfg.lib.vpn.isServer) cluster.hosts;
  bastion = head servers; # TODO check if there is only one bastion (put this check in the networking.vpn module)
  inherit (bastion.settings.services.kubernetes.vpn) cidr domain;
  inherit (config.lib.vpn) machineIp;
  # TODO populate privateKeyFile with agenix
  # "OE3AWnBnkZG9BVhb+RFy7sgeKvmnNBNSG+wkdHKMyXw=";
  vip = machineIp cidr hostVpn.id;
in {
  imports = [./fleet];

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
    networking = mkIf vpn.bastion.enable {
      wg-quick.interfaces.${vpn.interface}.peers =
        mkAfter
        mapAttrsToList (_: machine: {
          inherit (machine.settings.services.kubernetes.vpn) publicKey;
          allowedIPs = ["${machineIp cidr machine.settings.networking.vpn.id}/32"];
        })
        k8sHosts;

      # * We add the list of the hosts with their VPN IP and name + name.vpn-domain to /etc/hosts so dnsmasq can resolve them.
      hosts = (
        lib.mapAttrs' (name: _: lib.nameValuePair vip [name "${name}.${domain}"])
        k8sHosts
      );
    };

    system.activationScripts.kubernetes.text = let
      # not very elegant - would be nicer to access through pkgs.k3s-ca-certs instead
      generateCA = import ../../../packages/k3s-ca-certs.nix pkgs;
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

      kubeVipManifest = pkgs.writeText "kube-vip.yaml" readFile ./manifest.yaml;
    in
      # TODO apply secrets directly to avoid writing them to disk
      mkIf true (mkAfter ''
        ln -sf ${traefik} ${manifests}/traefik-config.yaml
        export VIP_ADDRESS="${vip}"
        export SERVER_IP=$(echo "${bastion.settings.networking.publicIP}" | base64 -w0)
        export SERVER_PUBLIC_KEY=$(echo "${bastion.settings.networking.vpn.publicKey}" | base64 -w0)
        export PRIVATE_KEY=$(cat "${vpn.privateKeyFile}" | base64 -w0)
        ${pkgs.vals}/bin/vals eval -f ${kubeVipManifest} > ${manifests}/kube-vip.yaml

      '');
  };
}
