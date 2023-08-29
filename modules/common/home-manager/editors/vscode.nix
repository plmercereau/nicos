{
  config,
  lib,
  pkgs,
  options,
  ...
}:
with lib; let
  inherit (config.lib) ext_lib;
  cfg = config.settings.users;
in {
  config = {
    home-manager.users = let
      mkHomeManagerUser = _: user: let
        userConfig = config.home-manager.users.${_};
        enable = userConfig.programs.vscode.enable;
        defaultEditor = enable && !userConfig.programs.helix.defaultEditor;
      in {
        programs.git.extraConfig = mkIf defaultEditor {
          core.editor = "code --wait";
          diff.tool = "vscode";
          difftool.vscode.cmd = "code --wait --diff $LOCAL $REMOTE";
          merge.tool = "vscode";
          mergetool.vscode.cmd = "code --wait $MERGED";
        };

        home.sessionVariables = mkIf defaultEditor {
          EDITOR = "code --wait";
        };
        programs.vscode = mkIf enable {
          # TODO move settings to the pilou user
          extensions = with pkgs.vscode-extensions;
            [
              jdinhlife.gruvbox
              bbenoist.nix
              kamadorueda.alejandra
              github.copilot
              ms-azuretools.vscode-docker
              yzhang.markdown-all-in-one
              esbenp.prettier-vscode
              vscode-icons-team.vscode-icons
              ms-vscode-remote.remote-ssh
              tamasfe.even-better-toml
              dbaeumer.vscode-eslint
              graphql.vscode-graphql
              redhat.vscode-yaml
            ]
            ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
              {
                name = "better-comments";
                publisher = "aaron-bond";
                version = "3.0.2";
                sha256 = "sha256-hQmA8PWjf2Nd60v5EAuqqD8LIEu7slrNs8luc3ePgZc=";
              }
              {
                name = "grammarly";
                publisher = "znck";
                version = "0.23.15";
                sha256 = "sha256-/LjLL8IQwQ0ghh5YoDWQxcPM33FCjPeg3cFb1Qa/cb0=";
              }
            ];
          userSettings = {
            "workbench.colorTheme" = "Gruvbox Dark Medium";
            "editor.inlineSuggest.enabled" = true;
            "window.zoomLevel" = 1.2;
            "git.confirmSync" = false;
            # Required when using zsh + powerlevel10k?
            "terminal.integrated.fontFamily" = "MesloLGS NF";
            "terminal.external.linuxExec" = "alacritty";
            "terminal.external.osxExec" = "Alacritty.app";
          };
          keybindings = [
            {
              key = "cmd+j";
              command = "workbench.action.terminal.toggleTerminal";
              when = "terminal.active";
            }
            {
              key = "cmd+1";
              command = "workbench.action.openEditorAtIndex1";
            }
            {
              key = "cmd+2";
              command = "workbench.action.openEditorAtIndex2";
            }
            {
              key = "cmd+3";
              command = "workbench.action.openEditorAtIndex3";
            }
            {
              key = "cmd+4";
              command = "workbench.action.openEditorAtIndex4";
            }
            {
              key = "cmd+5";
              command = "workbench.action.openEditorAtIndex5";
            }
            {
              key = "cmd+6";
              command = "workbench.action.openEditorAtIndex6";
            }
            {
              key = "cmd+7";
              command = "workbench.action.openEditorAtIndex7";
            }
            {
              key = "cmd+8";
              command = "workbench.action.openEditorAtIndex8";
            }
            {
              key = "cmd+9";
              command = "workbench.action.openEditorAtIndex9";
            }
          ];
        };
        # ! Ideally, should only install when the bbenoist.nix and kamadorueda.alejandra extensions are installed
        home.packages = mkIf enable (with pkgs; [
          alejandra
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
