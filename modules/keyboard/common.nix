{lib, ...}:
with lib; {
  options.settings.keyboard = {
    keyMapping = {
      enable = mkEnableOption "special key mappings";
    };
  };
}
