{ config, lib, pkgs, ... }:

with lib;

let
  inherit (config.lib) ext_lib;
  isDarwin = pkgs.hostPlatform.isDarwin;
  isLinux = pkgs.hostPlatform.isLinux;
  cfg = config.settings.users;
  hm = config.home-manager;
in
{

  config = {
    home-manager.users =
      let
        mkHomeManagerUser = _: user:
          let
            vscodeEnable = config.home-manager.users.${_}.programs.vscode.enable;
          in
          {
            programs.git.extraConfig = mkIf vscodeEnable {
              core.editor = "code --wait";
              diff.tool = "vscode";
              difftool.vscode.cmd = "code --wait --diff $LOCAL $REMOTE";
              merge.tool = "vscode";
              mergetool.vscode.cmd = "code --wait $MERGED";
            };

            home.sessionVariables = mkIf vscodeEnable {
              EDITOR = "code --wait";
            };
            home.packages = mkIf vscodeEnable (with pkgs;[
              nixpkgs-fmt # * required when using vscode & the nix plugin
            ]);
          };

        mkHomeManagerUsers = ext_lib.compose [
          (mapAttrs mkHomeManagerUser)
          # TODO recursion issue
          # (lib.filterAttrs (_: user: trace "ici" config.home-manager.users.${_}.programs.vscode.enable))
          ext_lib.filterEnabled
        ];
      in
      mkHomeManagerUsers cfg.users;
  };
}

