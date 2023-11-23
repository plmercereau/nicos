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
    # asciinema # Recording + sharing terminal sessions
    # navi # Interactive cheat sheet
    bandwhich # Bandwidth utilization monitor
    bitwarden-cli
    bind
    cocogitto
    ctop # container metrics & monitoring
    dogdns # better dig
    duf # better df
    fd # alternative to find
    fdupes # Duplicate file finder
    file
    git
    glances # Resource monitor + web
    gping # interactive ping
    jq
    killall
    lazydocker # Full Docker management app
    nmap
    nnn # file browser
    pstree # ps faux doesn't work on darwin
    speedtest-cli # Command line speed test utility
    tldr # complement to man
    tmux
    unzip
    wget
    wireguard-tools
  ];

  programs.git = {
    enable = true;

    lfs.enable = true;
    userName = fullName;
    userEmail = gitEmail;
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
    enable = true;
    settings = {
      git_protocol = "ssh";
      prompt = "enabled";
    };
  };

  # better find # ? too heavy to put as a common package?
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
