{lib, ...}:
with lib; {
  options.settings.keyboard = {
    keyMapping = {
      enable = mkEnableOption "Enable special key mappings";
    };
  };
}
