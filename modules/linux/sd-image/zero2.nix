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
  config = mkIf (platform == platforms.zero2) {
    sdImage = {
      # bzip2 compression takes loads of time with emulation, skip it. Enable this if you're low on space.
      compressImage = false;

      # Pi Zero 2 struggles to work without swap
      swap.enable = true;
      swap.size = 1024;
      extraFirmwareConfig = {
        # Give up VRAM for more Free System Memory
        # - Disable camera which automatically reserves 128MB VRAM
        start_x = 0;
        # - Reduce allocation of VRAM to 16MB minimum for non-rotated (32MB for rotated)
        gpu_mem = 16;
      };
    };
  };
}
