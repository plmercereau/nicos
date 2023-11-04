{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  isDarwin = pkgs.hostPlatform.isDarwin;
  applications = config.settings.applications;
  gui = config.settings.gui;
in {
  options.settings = {
    applications = {
      communication = {
        enable = mkEnableOption "enable communication applications";
      };
      development = {
        enable = mkEnableOption "enable development applications";
      };
      music = {
        enable = mkEnableOption "enable music applications";
      };
      office = {
        enable = mkEnableOption "enable office applications";
      };
      games = {
        enable = mkEnableOption "enable gaming applications";
      };
      # "cyberghost-vpn"
      # "arduino"
      # "signal" # linux: signal-desktop
    };
  };

  config = {
    programs.bash.enableCompletion = true;

    programs.zsh.enable = true;

    # * Required for zsh completion, see: https://nix-community.github.io/home-manager/options.html#opt-programs.zsh.enableCompletion
    environment.pathsToLink = ["/share/zsh"];

    # Common config for every machine (NixOS or Darwin)
    environment.systemPackages = (
      with pkgs;
        [
          curl
          e2fsprogs
          file
          git
          jq
          killall
          # TODO not working anymore
          # mkpasswd
          nnn # file browser
          speedtest-cli # Command line speed test utility
          tmux
          unzip
          wget
          wireguard-tools
        ]
        ++ (optionals gui.enable (
          [
            # TODO only install headless qbittorrent on the NUC
            pkgs.qbittorrent
            pkgs.iina
          ]
          ++ (optionals applications.development.enable ([
              dbeaver
              # TODO postman not working anymore
              #  postman
            ]
            ++ (optionals isDarwin [utm])))
          ++ (optionals applications.communication.enable [teams zoom-us])
          ++ (optionals applications.music.enable [spotify])
        ))
    );
  };
}
