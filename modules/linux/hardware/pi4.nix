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
    nixpkgs.hostPlatform = "aarch64-linux";
    hardware.enableRedistributableFirmware = true;
  };
}
