{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.bash.enableCompletion = true;

  # Common config for every machine
  environment.systemPackages = with pkgs; [
    curl
    e2fsprogs
  ];
}
