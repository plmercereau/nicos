# Generic Raspberry Pi Zero 2 configuration
{ pkgs, lib, config, ... }:
{
  settings.hardwarePlatform = config.settings.hardwarePlatforms.zero2;
  settings.profile = config.settings.profiles.minimal;
  settings.server.enable = true;
  sdImage.imageName = "nixos-sd-image-zero2.img";
}
