{
  config,
  lib,
  ...
}:
with lib; {
  options = {
    settings.keyboard = {
      keyMapping = {
        enable = mkEnableOption ''
          special key mappings.
            
          Swaps the CapsLock key with the Control key'';
      };
    };
  };

  config = {
    system.keyboard = lib.mkIf config.settings.keyboard.keyMapping.enable {
      enableKeyMapping = true;
      # Whether to remap the Caps Lock key to Control.
      remapCapsLockToControl = true;
    };
  };
}
