{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.settings.server;
in {
  options.settings = {
    server = {
      enable = mkEnableOption "is this machine a server";
    };
  };

  config = mkIf cfg.enable {
    settings.profile = config.settings.profiles.basic;
  };
}
