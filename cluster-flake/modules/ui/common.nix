{
  lib,
  pkgs,
  config,
  ...
}:
with lib; {
  options.settings = {
    windowManager = {
      enable = mkEnableOption "window manager";
    };
  };
}
