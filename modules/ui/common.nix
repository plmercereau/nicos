{
  lib,
  pkgs,
  config,
  ...
}:
with lib; {
  options.settings = {
    windowManager = {
      enable = mkEnableOption "the window manager";
    };
  };
}
