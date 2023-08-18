{ lib, options, config, modulesPath, ... }:
with lib;
let
  platform = config.settings.hardwarePlatform;
  platforms = config.settings.hardwarePlatforms;
in
{
  config = mkIf (platform == platforms.zero2) {
    nixpkgs.hostPlatform = "aarch64-linux";
  };
}
