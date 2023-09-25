{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  inherit (pkgs) stdenv;
  isDarwin = stdenv.isDarwin;
in {
  # ? load only if the user is using zsh?
  home.file.".zshrc".text = "";
  # For some reason skhd does not take /etc/skhd as the default config location anymore
  # home.file.".skhdrc" = mkIf isDarwin (mkIf (config.services.skhd.skhdConfig != "") {text = config.services.skhd.skhdConfig;});

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
}
