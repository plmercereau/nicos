{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.bash.enableCompletion = true;

  # Common config for every machine (NixOS or Darwin)
  environment.systemPackages = with pkgs; [
    curl
    e2fsprogs
  ];
}
