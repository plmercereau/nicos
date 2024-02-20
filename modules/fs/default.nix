{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.settings.services.fs;
in {
  options.settings.services.fs = {
    enable = mkOption {
      description = "Enable services related to better filesystem management, for instance fstrim and udisks2.";
      type = types.bool;
      default = true;
    };
  };

  config.services = mkIf cfg.enable {
    # https://man7.org/linux/man-pages/man8/fstrim.8.html
    fstrim.enable = true;

    # Avoid pulling in unneeded dependencies
    udisks2.enable = lib.mkDefault false;
  };
}
