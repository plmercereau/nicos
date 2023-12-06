{
  lib,
  pkgs,
  ...
}: let
  fullName = "Pierre-Louis Mercereau";
  gitEmail = "24897252+plmercereau@users.noreply.github.com";
in {
  imports = [
    ./common.nix
  ];
  programs.helix.defaultEditor = true;

  home.packages = with pkgs; [
    bandwhich # Bandwidth utilization monitor
    bind
    dogdns # better dig
    duf # better df
    fd # alternative to find
    file
    git
    glances # Resource monitor + web
    gping # interactive ping
    jq
    killall
    pstree # ps faux doesn't work on darwin
    speedtest-cli # Command line speed test utility
    tmux
    wget
    wireguard-tools
  ];

  programs.git = {
    userName = fullName;
    userEmail = gitEmail;
  };

  # better find # ? too heavy to put as a minimal package?
  programs.fzf.enable = true;

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
