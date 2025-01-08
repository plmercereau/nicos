{
  config,
  lib,
  pkgs,
  cluster,
  ...
}:
with lib; let
  inherit (config.settings) fleet-manager;
  cfg = config.settings.local-server;
in {
  options.settings.local-server.enable = mkOption {
    description = ''
      Label this machine as a local server.
    '';
    type = types.bool;
    default = !fleet-manager.enable;
  };

  config.settings.kubernetes.labels.local-server = (
    if cfg.enable
    then "enabled"
    else "disabled"
  );
}
