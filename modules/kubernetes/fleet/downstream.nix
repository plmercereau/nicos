{
  config,
  lib,
  pkgs,
  cluster,
  ...
}:
with lib; let
  k8s = config.settings.kubernetes;
  fleet = k8s.fleet;

  upstreamMachine =
    findFirst
    (host: host.settings.kubernetes.fleet.upstream.enable)
    (builtins.throw "No upstream machine found")
    (attrValues cluster.hosts);
in {
  config = mkIf (k8s.enable && fleet.enable && !fleet.upstream.enable) {
    # * Install the Fleet Agent as a k3s manifest
    system.activationScripts.kubernetes-fleet-agent.text = ''
      ${pkgs.k3s-chart {
        name = "fleet-agent";
        namespace = fleet.fleetNamespace;
        repo = "https://rancher.github.io/fleet-helm-charts";
        chart = "fleet-agent";
        version = fleet.helmChartVersion;
      }}
    '';

    # * Make sure the Fleet Agent gets the upstream credentials
    systemd.services.k3s-fleet-agent-config = {
      wantedBy = ["multi-user.target"];
      after = ["network.target" "k3s.service"];
      wants = ["k3s.service"];
      description = "checking fleet-agent handshake with upstream server";
      environment = {
        KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = let
          secretName = "fleet-agent";
        in
          pkgs.writeShellScript "check-fleet-agent-config" ''
            MAX_RETRIES=180
            RETRY_DELAY=3
            secret_exists() {
              ${pkgs.kubectl}/bin/kubectl get secret ${secretName} --namespace=${fleet.fleetNamespace} &>/dev/null
            }
            create_config() {
              # * Try to update the Helm Chart Config file with the values from the upstream server
              while true; do
                echo "Creating Helm Chart Config..."
                VALUES=$(${pkgs.openssh}/bin/ssh -i /etc/ssh/ssh_host_ed25519_key ${fleet.connectionUser}@${upstreamMachine.networking.hostName})
                if [ $? -eq 0 ]; then
                  ${pkgs.k3s-chart-config "fleet-agent"} "$VALUES"
                  echo "fleet-agent HelmChartConfig updated."
                  # * after the Helm Chart Config file is updated, restart the systemd service
                  exit 1
                fi
                sleep 1
              done
            }
            # TODO look for the HelmChartConfig resource in the cluster instead
            if [ -f "/var/lib/rancher/k3s/server/manifests/fleet-agent-config.yaml" ]; then
              echo "HelmChartConfig file exists. Checking for secret ${secretName}."
              for (( i=0; i<MAX_RETRIES; i++ )); do
                if secret_exists; then
                  echo "Secret ${secretName} found after $((i+1)) attempt(s). Assuming fleet-agent is connnected to the upstream manager."
                  exit 0
                else
                  echo "Check $((i+1))/$MAX_RETRIES"
                  sleep $RETRY_DELAY
                fi
              done
              echo "Secret ${secretName} not found."
              create_config
            else
              echo "HelmChartConfig file doesn't exist."
              create_config
            fi
          '';
        Restart = "on-failure";
        RestartSec = 3;
        RemainAfterExit = "no";
      };
    };
  };
}
