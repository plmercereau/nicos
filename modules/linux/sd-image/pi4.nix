{ lib, options, config, modulesPath, ... }:
with lib;
let
  platform = config.settings.hardwarePlatform;
  platforms = config.settings.hardwarePlatforms;
in
{
  config = mkIf (platform == platforms.pi4) {
    # TODO override default option value to "false"
    # bzip2 compression takes loads of time with emulation, skip it. Enable this if you're low on space.
    sdImage.compressImage = false;
  };
}
