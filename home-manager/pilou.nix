{
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./pilou-minimal.nix
  ];

  home.packages = with pkgs; [
    # asciinema # Recording + sharing terminal sessions
    # navi # Interactive cheat sheet
    bitwarden-cli
    cocogitto
    ctop # container metrics & monitoring
    fdupes # Duplicate file finder
    go-task
    lazydocker # Full Docker management app
    nmap
    nnn # file browser
    rclone
    tldr # complement to man
    unzip
  ];

  # * See: https://mipmip.github.io/home-manager-option-search/?query=programs.gh
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
      prompt = "enabled";
    };
  };
}
