{
  pkgs,
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.settings.git;
in {
  options = {
    settings.git = {
      repos = mkOption {
        type = types.attrsOf types.path;
        description = ''
          Set of local git repositories to be committed locally on each activation.
        '';
        default = {};
      };

      basePath = mkOption {
        type = types.path;
        internal = true;
        readOnly = true;
        default = "/var/lib/nicos/git";
      };
    };
  };

  config = {
    system.activationScripts = mapAttrs' (name: localRepo:
      nameValuePair "sync-local-git-repo-${name}" {
        text = let
          repoPath = "${cfg.basePath}/${name}";
        in ''
          mkdir -p ${repoPath}
          cd ${repoPath}
          ${pkgs.git}/bin/git config --global --add safe.directory ${repoPath}
          ${pkgs.git}/bin/git config user.email "nixos@local"
          ${pkgs.git}/bin/git config user.name "NixOS system"
          ${pkgs.git}/bin/git init -b main
          touch .git/git-daemon-export-ok
          # * Remove everything, including hidden dot files
          shopt -s dotglob
          ${pkgs.git}/bin/git rm -r . 2>/dev/null || true
          # * Copy everything from the derivation
          ${pkgs.rsync}/bin/rsync -aL --chmod=755 ${localRepo}/ ${repoPath}/
          ${pkgs.git}/bin/git add .
          ${pkgs.git}/bin/git commit -m "chore: commit from nixos activation" || true
        '';
      })
    cfg.repos;
  };
}
