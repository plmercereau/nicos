{
  lib,
  options,
  config,
  modulesPath,
  ...
}:
with lib; let
  platform = config.settings.hardwarePlatform;
  platforms = config.settings.hardwarePlatforms;
in {
  config = mkIf (platform == platforms.pi4) {
    sdImage = {
      # bzip2 compression takes loads of time with emulation, skip it. Enable this if you're low on space.
      compressImage = false;

      swap.enable = true;
      swap.size = 2048;
    };
  };
}
