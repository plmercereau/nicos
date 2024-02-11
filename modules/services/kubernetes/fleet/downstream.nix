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
in {
  config = mkIf (k8s.enable && cfg.enable && isDownstream) {
    # * Once k3s is up, send the kubeconfig to the upstream server. Run only once.
    systemd.services.k3s-config-upload = {
      wantedBy = ["multi-user.target"];
      after = ["network.target" "k3s.service"];
      wants = ["k3s.service"];
      description = "Send the kubeconfig of the machine to the upstream server.";
      serviceConfig = {
        Type = "simple";
        ExecStart = let
          lockFile = "/var/lib/nicos/fleet.ok";
        in
          pkgs.writeShellScript "send-fleet-kubeconfig" ''
            if [[ -e "${lockFile}" ]]; then
                echo "Script has already run. Exiting."
                exit 0
            fi
            while true; do
            if ${pkgs.openssh}/bin/ssh -i /etc/ssh/ssh_host_ed25519_key ${cfg.connectionUser}@${upstreamMachine.lib.vpn.ip} "$(cat /etc/rancher/k3s/k3s.yaml)"; then
              # Create flag file to indicate script has run
              mkdir -p "$(dirname "${lockFile}")"
              touch "${lockFile}"
              echo "Secret pushed to the upstream server. Created ${lockFile} to indicate script has run. Exiting."
              exit 0
            else
              # Capture and print the error
              error=$?
              echo "Command failed with error code $error. Retrying in 10 seconds..."
              sleep 10
            fi
            done
          '';
        Restart = "on-failure";
        RestartSec = 3;
        RemainAfterExit = "no";
      };
    };
  };
}
