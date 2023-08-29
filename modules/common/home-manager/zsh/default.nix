{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  inherit (config.lib) ext_lib;
  cfg = config.settings.users;
in {
  config = {
    # * Required for zsh completion, see: https://nix-community.github.io/home-manager/options.html#opt-programs.zsh.enableCompletion
    environment.pathsToLink = ["/share/zsh"];

    home-manager.users = let
      mkHomeManagerUser = _: user: let
        # vscodeEnable = config.home-manager.users.${_}.programs.vscode.enable;
      in {
        # TODO load only if the user is using zsh?
        home.file.".zshrc".text = "";
        programs.zsh = {
          enable = true;
          enableCompletion = true;
          enableAutosuggestions = true;
          syntaxHighlighting.enable = true;
          autocd = true;
          dotDir = ".config/zsh";
          plugins = [
            {
              name = "powerlevel10k";
              src = pkgs.zsh-powerlevel10k;
              file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
            }
          ];
          oh-my-zsh = {
            enable = true;
            plugins = [
              "colored-man-pages" # * Man pages in color. See: https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/colored-man-pages
              "git" # * Git aliases & functions. See: https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/git
              # "globalias" # * Expands all glob expressions, subcommands and aliases. See: https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/globalias
            ];
          };
          initExtra = let
            zshrc = builtins.readFile ./zshrc;
            p10k = builtins.readFile ./p10k.zsh;
          in ''
            ${p10k}
            ${zshrc}
          '';
        };
      };

      mkHomeManagerUsers = ext_lib.compose [
        (mapAttrs mkHomeManagerUser)
        ext_lib.filterEnabled
      ];
    in
      mkHomeManagerUsers cfg.users;
  };
}
