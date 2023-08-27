{ config, lib, pkgs, options, ... }:

with lib;

let
  inherit (config.lib) ext_lib;
  cfg = config.settings.users;

in
{
  config = {
    home-manager.users =
      let
        mkHomeManagerUser = _: user:
          let
            userConfig = config.home-manager.users.${_};
            enable = userConfig.programs.vscode.enable;
            defaultEditor = enable && !userConfig.programs.helix.defaultEditor;
          in
          {
            # TODO additional params: https://mipmip.github.io/home-manager-option-search/?query=programs.vscode
            programs.git.extraConfig = mkIf defaultEditor {
              core.editor = "code --wait";
              diff.tool = "vscode";
              difftool.vscode.cmd = "code --wait --diff $LOCAL $REMOTE";
              merge.tool = "vscode";
              mergetool.vscode.cmd = "code --wait $MERGED";
            };

            # TODO settings.users.<user>.editor = pkgs.vscode or pkgs.neovim or pkgs.helix
            home.sessionVariables = mkIf defaultEditor {
              EDITOR = "code --wait";
            };
            home.packages = mkIf enable (with pkgs;[
              # ? use alejandra?
              # TODO in any case, configure vscode plugins
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

