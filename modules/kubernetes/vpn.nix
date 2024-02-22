{
  config,
  lib,
  pkgs,
  cluster,
  ...
}:
with lib; let
  inherit (config.settings) kubernetes vpn;
  inherit (config.lib.vpn) machineIp bastion;
  inherit (config.lib.kubernetes) hosts;

  inherit (bastion.settings.kubernetes.vpn) cidr domain;
  inherit (bastion.settings.vpn.bastion) extraPeers;
in {
  # TODO should be defined in the bastion
  options.settings.kubernetes.vpn = {
    cidr = mkOption {
      # TODO check for conflicts with settings.vpn.cidr
      description = ''
        CIDR that defines the VPN network of the Kubernetes cluster.
      '';
      type = types.str;
      default = "10.101.0.0/24";
    };
    domain = mkOption {
      # TODO check for conflicts with settings.vpn.domain
      description = ''
        Domain name of the cluster.

        The clusters will then be accessible through `hostname.domain`.
      '';
      type = types.str;
      default = "cluster";
    };
  };

  config = mkMerge [
    {
      lib.kubernetes = rec {
        # * Returns the VPN IP address of the current cluster.
        ip = machineIp cidr config.settings.vpn.id;
        fqdn = "${config.networking.hostName}.${domain}";

        # * Returns the VPN IP address of the current cluster with the VPN network mask.
        ipWithMask = "${ip}/${toString (config.lib.network.ipv4.cidrToBitMask cidr)}";
      };
    }

    (mkIf vpn.bastion.enable {
      settings.vpn.peers = (
        mapAttrs' (_: machine: nameValuePair machine.publicKey ["${machineIp cidr machine.id}/32"])
        ( # Add the list of the client machines configured in the cluster of machines
          (mapAttrs (_: machine: {inherit (machine.settings.vpn) id publicKey;}) hosts)
          // vpn.bastion.extraPeers # Also allow an IP for the extra peers
        )
      );

      # * Add the k8s vpn address to the bastion
      networking.wg-quick.interfaces.wg0.address = [config.lib.kubernetes.ipWithMask];

      # * We add the list of the hosts with k8s enabled with vpn with their VPN IP and name.vpn-domain to /etc/hosts so dnsmasq can resolve them.
      services.dnsmasq.settings.address =
        lib.mapAttrsToList (name: machine: "/${machine.lib.kubernetes.fqdn}/${machine.lib.kubernetes.ip}") hosts;
    })

    (
      mkIf (kubernetes.enable && vpn.enable) {
        system.activationScripts = {
          kubernetes.text = mkAfter ''
            ${pkgs.k3s-chart {
              name = "kube-vip";
              namespace = "kube-system";
              src = ../../charts/kube-vip;
            }}
          '';
        };

        # * Update the fleet helm values in the k3s manifests after the k3s service is up, so it gets the correct CA certificate
        systemd.services.kube-vip = {
          wantedBy = ["multi-user.target"];
          after = ["k3s.service"];
          wants = ["k3s.service"];
          description = "update the kube-vip secret and manifest after k3s is up";
          environment = {
            KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
          };
          serviceConfig = {
            Type = "simple";
            # TODO insert the sha256sum of the secret into the kube-vip manifest (spec.template.metadata.annotations.secret-hash) so the kube-vip pods are restarted when the secret changes
            # TODO best then to include the wireguard secret to the helm values so helm takes care of the hash?
            # TODO but then, the helm chart operator should NOT store the secret in clear in the HelmChartConfig...
            # TODO another option would be to use fleet direclty.
            # TODO but then we cannot get rid of the "vpn ip" dependency
            # TODO ->>> %{KUBERNETES_API}% -> %{NODE_IP_XXX}% variable ->>> probably a dead end
            # TODO maybe better to review this "local git daemon":
            # A. use a remote git repo (but then how to run in dev mode?). And then "clusters" would be embedded into a HelmChart/HelmChartConfig so they can be updated/removed
            # B. run a git daemon inside the cluster with a link to the host filesystem
            ExecStart = pkgs.k8s-apply-secret {
              name = "wireguard";
              namespace = "kube-system";
              values = {
                peerEndpoint = bastion.settings.publicIP;
                peerPublicKey = bastion.settings.vpn.publicKey;
                privateKey.file = config.age.secrets.vpn.path;
              };
              wait = true;
            };
            Restart = "on-failure";
            RestartSec = 3;
            RemainAfterExit = "no";
          };
        };
      }
    )
  ];
}
