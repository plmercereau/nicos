{
  lib,
  pkgs,
  ...
}: {
  imports = [./raspberry-pi.nix];

  sdImage.extraFirmwareConfig = {
    # Give up VRAM for more Free System Memory
    # - Disable camera which automatically reserves 128MB VRAM
    start_x = 0;
    # - Reduce allocation of VRAM to 16MB minimum for non-rotated (32MB for rotated)
    gpu_mem = 16;
    # Configure display to 800x600
    # * See: https://elinux.org/RPi_Configuration
    hdmi_group = 2;
    hdmi_mode = 8;
    # dtoverlay = "dwc2";
    # modules-load = "dwc2";
  };

  # Keep this, it works
  hardware.enableRedistributableFirmware = lib.mkForce false;
  hardware.firmware = [pkgs.raspberrypiWirelessFirmware];

  nix.settings.cores = lib.mkDefault 4;
}
