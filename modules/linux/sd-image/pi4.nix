{
  lib,
  options,
  config,
  modulesPath,
  ...
}:
with lib; let
  platform = config.settings.hardware;
  platforms = config.settings.hardwares;
in {
  config = mkIf (platform == platforms.pi4) {
    sdImage = {
      # bzip2 compression takes loads of time with emulation, skip it. Enable this if you're low on space.
      compressImage = false;
      imageName = "nixos-sd-image-pi4.img";

      swap.enable = true;
      swap.size = 2048;
    };
  };
}
