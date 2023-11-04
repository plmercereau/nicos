{
  config,
  lib,
  ...
}: {
  system.keyboard = lib.mkIf config.settings.keyMapping.enable {
    enableKeyMapping = true;
    # Whether to remap the Caps Lock key to Control.
    remapCapsLockToControl = true;
  };
}
