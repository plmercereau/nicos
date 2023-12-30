{lib, ...}:
with lib; {
  options.settings.keyboard = {
    keyMapping = {
      enable = mkEnableOption ''
        special key mappings.
              
        On Darwin, it swaps the CapsLock key with the Control key'';
    };
  };
}
