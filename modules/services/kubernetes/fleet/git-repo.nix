{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  k8s = config.settings.services.kubernetes;
  cfg = k8s.fleet;
  basePath = "/var/lib/nicos/git";
  repoName = "fleet";
  repoPath = "${basePath}/${repoName}";

  # TODO the git-daemon works on my machine, but maybe because it is resolved through my router DNS. I need to test it on a hetzner machine
  # TODO this external service doen't work:
  /*
  ---
  kind: Service
  apiVersion: v1
  metadata:
     name: git-daemon
     namespace: ${cfg.namespace}
  spec:
     type: ExternalName
     externalName: ${config.networking.hostName}
     ports:
     - port: ${toString config.services.gitDaemon.port}
  */
  fleetGitManifest = pkgs.writeText "git-repo.yaml" ''
    kind: GitRepo
    apiVersion: fleet.cattle.io/v1alpha1
    metadata:
        name: fleet-git
        namespace: ${
      if cfg.mode == "standalone"
      then "fleet-local"
      else cfg.clustersNamespace
    }
    spec:
        repo: git://${config.networking.hostName}:${toString config.services.gitDaemon.port}/${repoName}
        branch: main
        paths:
            - "*"
  '';
  # TODO only as an example. Make it more generic
  apache = import ./apache {inherit pkgs;};
in {
  config = mkIf (k8s.enable
    && cfg.enable
    && (cfg.mode != "downstream")) {
    services.gitDaemon = {
      enable = true;
      inherit basePath;
      repositories = [repoPath];
    };

    system.activationScripts = {
      kubernetes-fleet-git-repo-manifest.text = ''
        mkdir -p /var/lib/rancher/k3s/server/manifests
        ln -sf ${fleetGitManifest} /var/lib/rancher/k3s/server/manifests/fleet-git-repo.yaml
      '';
      kubernetes-fleet-git-repo-sync.text = let
        syncRepo = pkgs.writeScript "sync-repo" ''
          set -e
          cd ${repoPath}
          umask 022
          ${pkgs.git}/bin/git init -b main
          ${pkgs.git}/bin/git config user.email "nixos@local"
          ${pkgs.git}/bin/git config user.name "NixOS Fleet activation script"
          touch .git/git-daemon-export-ok
          # * Remove everything, including hidden dot files
          shopt -s dotglob
          ${pkgs.git}/bin/git rm -r . 2>/dev/null || true
          # * Copy everything from the derivation
          # TODO this is only an example with Apache. Make it more generic
          # TODO for now, fleet won't deploy anything in the upstream server (we should tag the resources with "fleet-local" namespace)
          ${pkgs.rsync}/bin/rsync -a --chmod=740 ${apache}/ ${repoPath}/
          ${pkgs.git}/bin/git add .
          # TODO improve the commit message
          ${pkgs.git}/bin/git commit -m "chore: commit" || true
        '';
      in ''
        mkdir -p ${repoPath}
        chown ${config.services.gitDaemon.user}:${config.services.gitDaemon.group} ${basePath}
        ${pkgs.sudo}/bin/sudo -u ${config.services.gitDaemon.user} ${syncRepo}
      '';
    };
  };
}
