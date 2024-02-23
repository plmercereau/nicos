{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.bash.enableCompletion = true;

  # Packages that should always be available for manual intervention
  environment.systemPackages = with pkgs; [curl e2fsprogs];
}
