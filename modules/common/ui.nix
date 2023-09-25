{
  lib,
  pkgs,
  config,
  ...
}:
with lib; let
  isDarwin = pkgs.hostPlatform.isDarwin;
in {
  options.settings.gui = {
    enable = lib.mkOption {
      type = types.bool;
      default = isDarwin;
      description = "Enable the UI for this machine";
    };
    windowManager = {
      enable = mkEnableOption "window manager";
    };
  };
}
