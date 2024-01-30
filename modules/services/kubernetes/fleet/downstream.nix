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
    (host: host.nixpkgs.hostPlatform.isLinux && host.settings.services.kubernetes.fleet.mode == "upstream")
    (builtins.throw "No upstream machine found")
    (attrValues cluster.hosts);

  script = let
    clusterUrl = "https://${config.networking.hostName}.${config.settings.networking.vpn.domain}:6443";
  in
    pkgs.writeScript "send-fleet-kubeconfig" ''
      FLAG_FILE="/var/lib/nicos/fleet.ok"
      if [[ -e "$FLAG_FILE" ]]; then
          echo "Script has already run. Exiting."
          exit 0
      fi
      ${pkgs.openssh}/bin/ssh -i /etc/ssh/ssh_host_ed25519_key ${cfg.connectionUser}@${upstreamMachine.networking.hostName}.${upstreamMachine.settings.networking.vpn.domain} "$(cat /etc/rancher/k3s/k3s.yaml)"
      # Create flag file to indicate script has run
      mkdir -p "$(dirname "$FLAG_FILE")"
      touch "$FLAG_FILE"
    '';
in {
  # TODO assertion: an active upstream machine exists if the machine is downstream
  config = mkIf (k8s.enable && cfg.enable && isDownstream) {
    systemd.services.sendFleetKubeConfigInUpstream = {
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
      description = "Send the kubeconfig of the machine to the upstream server.";
      serviceConfig = {
        # TODO not correctly configured
        Type = "simple";
        ExecStart = ''${script}'';
        Restart = "on-failure";
        RestartSec = 60;
        # RemainAfterExit = "no";
      };
    };
  };
}
