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
    home-manager.users = let
      mkHomeManagerUser = _: user:
        config.lib.ext_lib.recursiveMerge [
          {
            #   # ? move to hm-imports?
            home.stateVersion = mkDefault "23.05";

            home.packages = with pkgs; [
              eza
              bitwarden-cli
              cocogitto
              bandwhich # Bandwidth utilization monitor
              ctop # container metrics & monitoring
              deno
              dogdns # better dig
              duf # better df
              fd # alternative to find
              fdupes # Duplicate file finder
              glances # Resource monitor + web
              gping # interactive ping
              lazydocker # Full Docker management app
              nmap
              pstree # ps faux doesn't work on darwin
              tldr # complement to man
              # asciinema # Recording + sharing terminal sessions
              # navi # Interactive cheat sheet
            ];

            # ! complete configuration when neomutt works
            accounts.email.accounts.${user.name} = {
              address = user.email;
              userName = user.name;
              realName = user.fullName;
              primary = true;
              neomutt = {
                enable = true;
                sendMailCommand = "msmtpq --read-envelope-from --read-recipients";
              };
              smtp = {
                host = "";
                port = 465;
              };
              signature.text = ''
                ${user.fullName}
              '';
            };

            home.shellAliases = {
              # v = "nvim";
              # vim = "nvim";
              gpl = "git pull";
              gp = "git push";
              # lg = "lazygit";
              gc = "git commit -v";
              kb = "git commit -m \"\$(curl -s http://whatthecommit.com/index.txt)\"";
              gs = "git status -v";
              gfc = "git fetch && git checkout";
              gl = "git log --graph";
              l = "eza -la --git";
              la = "eza -a --git";
              ls = "eza";
              ll = "eza -l --git";
              lla = "eza -la --git";
            };

            # better wget
            programs.aria2.enable = true;

            programs.bat = {
              enable = true;
              config.theme = "gruvbox-dark";
            };

            programs.dircolors.enable = true;

            programs.direnv = {
              # Direnv, load and unload environment variables depending on the current directory.
              # https://direnv.net
              # https://rycee.gitlab.io/home-manager/options.html#opt-programs.direnv.enable

              enable = true;
              # Zsh integration is manually enabled in zshrc in order to mute some of direnv's output
              enableZshIntegration = false;
              nix-direnv.enable = true;

              # devenv can be slow to load, we don't need a warning every time
              config.global.warn_timeout = "3m";
            };
            # better find # ? too heavy to put as a common package?
            programs.fzf.enable = true;

            programs.git = {
              enable = true;

              lfs.enable = true;
              userName = user.fullName;
              userEmail = user.gitEmail;
              extraConfig = {
                # user.signingKey = "DA5D9235BD5BD4BD6F4C2EA868066BFF4EA525F1";
                # commit.gpgSign = true;
                init.defaultBranch = "main";
                alias.root = "rev-parse --show-toplevel";
              };
              diff-so-fancy.enable = true;

              ignores = [
                "*~"
                ".DS_Store"
                ".direnv"
                "/direnv"
                "/direnv.test"
                ".AppleDouble"
                ".LSOverride"
                "Icon"
                "._*"
                ".DocumentRevisions-V100"
                ".fseventsd"
                ".Spotlight-V100"
                ".TemporaryItems"
                ".Trashes"
                ".VolumeIcon.icns"
                ".com.apple.timemachine.donotpresent"
                ".AppleDB"
                ".AppleDesktop"
                "Network Trash Folder"
                "Temporary Items"
                ".apdisk"
              ];
            };

            # * See: https://mipmip.github.io/home-manager-option-search/?query=programs.gh
            programs.gh = {
              settings = {
                git_protocol = "ssh";
                prompt = "enabled";
              };
            };

            programs.helix.enable = true;

            # Htop configurations
            programs.htop = {
              enable = true;
              settings = {
                hide_userland_threads = true;
                highlight_base_name = true;
                shadow_other_users = true;
                show_program_path = false;
                tree_view = false;
              };
            };

            programs.tmux = {
              enable = true;
              # keyMode = "vi";
              clock24 = true;
              historyLimit = 10000;
              plugins = with pkgs.tmuxPlugins; [
                # vim-tmux-navigator
                gruvbox
              ];
              extraConfig = ''
                set -sg escape-time 0 # makes vim esc usable
                new-session -s main
                # bind-key -n C-e send-prefix
                # bind '"' split-window -c "#{pane_current_path}"
                # bind % split-window -h -c "#{pane_current_path}"
                # bind c new-window -c "#{pane_current_path}"
                set-option -g default-terminal "tmux-256color"
                set -as terminal-overrides ',xterm*:Tc:sitm=\E[3m'
              '';
            };
          }
          user.hm
        ];

      mkHomeManagerUsers = ext_lib.compose [
        (mapAttrs mkHomeManagerUser)
        ext_lib.filterEnabled
      ];
    in
      mkHomeManagerUsers cfg.users;
  };
}
