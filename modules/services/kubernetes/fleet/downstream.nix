{
  config,
  lib,
  pkgs,
  cluster,
  ...
}:
with lib; let
  k8s = config.settings.services.kubernetes;
  cfg = k8s.fleet;
  isDownstream = cfg.mode == "downstream";

  upstreamMachine =
    findFirst
    (host: host.nixpks.hostPlatform.isLinux && host.settings.services.kubernetes.fleet.mode == "upstream")
    (attrValues cluster.hosts);

  patchKubeConfigDrv = upstreamMachine.lib.fleet.patchKubeConfigDrvs.${config.networking.hostName};
in {
  # TODO assertion: an active upstream machine exists if the machine is downstream
  config = mkIf (k8s.enable && cfg.enable && isDownstream) {
    systemd.services.sendFleetKubeConfigInUpstream = {
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
      description = "Send the kubeconfig of the machine to the upstream server.";
      serviceConfig = {
        Type = "simple";
        ExecStart = pkgs.writeScript "send-fleet-kubeconfig-in-upstream.sh" ''
          FLAG_FILE="/var/lib/nicos/fleet.ok"
          if [[ -e "$FLAG_FILE" ]]; then
              echo "Script has already run. Exiting."
              exit 0
          fi
          KUBECONFIG=$(cat /etc/rancher/k3s/k3s.yaml | base64 -w0)
          ${pkgs.openssh}/bin/ssh ${cfg.connectionUser}@${ds.network.hostName}.${config.settings.networking.vpn.domain} "${patchKubeConfigDrv} $KUBECONFIG"
          # Create flag file to indicate script has run
          mkdir -p "$(dirname "$FLAG_FILE")"
          touch "$FLAG_FILE"
        '';
        Restart = "on-failure";
        RestartSec = 60;
        RemainAfterExit = "no";
      };
    };
  };
}
