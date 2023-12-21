{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  isDarwin = pkgs.hostPlatform.isDarwin;
  applications = config.settings.applications;
in {
  programs.bash.enableCompletion = true;

  programs.zsh.enable = true;

  # * Required for zsh completion, see: https://nix-community.github.io/home-manager/options.html#opt-programs.zsh.enableCompletion
  environment.pathsToLink = ["/share/zsh"];

  # Common config for every machine (NixOS or Darwin)
  environment.systemPackages = with pkgs; [
    curl
    e2fsprogs
  ];
}
