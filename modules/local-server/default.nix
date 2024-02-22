{
  config,
  lib,
  pkgs,
  cluster,
  ...
}:
with lib; let
  inherit (config.settings) fleet;
  cfg = config.settings.local-server;
in {
  options.settings.local-server.enable = mkOption {
    description = ''
      Label this machine as a local server.
    '';
    type = types.bool;
    default = fleet.enable && (!fleet.upstream.enable);
  };

  config.settings.fleet.labels.local-server =
    mkIf fleet.enable
    (
      if cfg.enable
      then "enabled"
      else "disabled"
    );
}
