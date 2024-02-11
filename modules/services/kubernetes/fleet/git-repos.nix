{
  pkgs,
  config,
  lib,
  ...
}:
with lib; let
  k8s = config.settings.services.kubernetes;
  fleet = k8s.fleet;
in {
  config = mkIf (k8s.enable && fleet.enable) {
    # * Sync any potential local git repos to the git daemon
    settings.services.gitDaemon.repos =
      mapAttrs'
      (name: localRepo: nameValuePair "fleet-${name}" localRepo.package)
      fleet.localGitRepos;

    # * Any local git repo is registered as a fleet git repo
    settings.services.kubernetes.fleet.gitRepos = mapAttrs' (name: localRepo:
      nameValuePair "local-${name}"
      {
        inherit (localRepo) namespace branch paths targets;
        repo = "git://${config.lib.vpn.ip}:${toString config.services.gitDaemon.port}/fleet-${name}";
      })
    fleet.localGitRepos;

    # * Create a symlink to every git repo manifest in the k3s server manifests directory
    # TODO ideally we should remove all previous symlinks prior to these activation scripts
    system.activationScripts = mapAttrs' (name: gitRepo:
      nameValuePair "symlink-git-repo-manifest-${name}" {
        text = let
          manifest = pkgs.writeText "git-repo-${name}.yaml" ''
            kind: GitRepo
            apiVersion: fleet.cattle.io/v1alpha1
            metadata:
                name: ${name}
                namespace: ${gitRepo.namespace}
            spec:
                repo: ${gitRepo.repo}
                branch: ${gitRepo.branch}
                paths: ${strings.toJSON gitRepo.paths}
                targets: ${strings.toJSON gitRepo.targets}
          '';
          dest = "/var/lib/rancher/k3s/server/manifests";
        in ''
          mkdir -p ${dest}
          ln -sf ${manifest} ${dest}/fleet-git-repo-${name}.yaml
        '';
      })
    fleet.gitRepos;
  };
}
