{
  pkgs,
  config,
  lib,
  ...
}:
with lib; let
  basePath = "/var/lib/nicos/git";
  cfg = config.settings.gitDaemon;
in {
  options = {
    settings.gitDaemon = {
      repos = mkOption {
        type = types.attrsOf types.path;
        description = "TODO";
        default = {};
      };
    };
  };

  config = {
    services.gitDaemon = {
      enable = length (attrNames cfg.repos) > 0;
      inherit basePath;
      repositories = mapAttrsToList (name: _: "${basePath}/${name}") cfg.repos;
    };

    system.activationScripts = mapAttrs' (name: localRepo:
      nameValuePair "sync-local-git-repo-${name}" {
        text = let
          repoPath = "${basePath}/${name}";
          syncRepo = pkgs.writeScript "sync-repo" ''
            set -e
            cd ${repoPath}
            umask 027
            ${pkgs.git}/bin/git init -b main
            ${pkgs.git}/bin/git config user.email "nixos@local"
            ${pkgs.git}/bin/git config user.name "NixOS system"
            touch .git/git-daemon-export-ok
            # * Remove everything, including hidden dot files
            shopt -s dotglob
            ${pkgs.git}/bin/git rm -r . 2>/dev/null || true
            # * Copy everything from the derivation
            ${pkgs.rsync}/bin/rsync -a --chmod=750 ${localRepo}/ ${repoPath}/
            ${pkgs.git}/bin/git add .
            ${pkgs.git}/bin/git commit -m "chore: commit from nixos activation" || true
          '';
        in ''
          mkdir -p ${repoPath}
          chown ${config.services.gitDaemon.user}:${config.services.gitDaemon.group} ${basePath} ${repoPath}
          ${pkgs.sudo}/bin/sudo -u ${config.services.gitDaemon.user} ${syncRepo}
        '';
      })
    cfg.repos;
  };
}
