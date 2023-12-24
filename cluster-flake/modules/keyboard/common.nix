{lib, ...}:
with lib; {
  options.settings = {
    # TODO rename to keyboard.keyMapping.enable
    keyMapping = {
      enable = mkEnableOption "Enable special key mappings";
    };
  };
}
