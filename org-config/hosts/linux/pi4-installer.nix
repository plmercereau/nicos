# Generic Raspberry Pi 4 configuration
{ pkgs, lib, config, ... }:
{
  settings.hardwarePlatform = config.settings.hardwarePlatforms.pi4;
  settings.profile = config.settings.profiles.minimal;
  settings.server.enable = true;
  sdImage.imageName = "nixos-sd-image-pi4.img";
}
