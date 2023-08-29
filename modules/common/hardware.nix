{
  lib,
  options,
  config,
  ...
}:
with lib; let
  platform = config.settings.hardwarePlatform;
  platforms = config.settings.hardwarePlatforms;
in {
  options.settings = {
    hardwarePlatforms = mkOption {
      type = types.attrsOf types.str;
      description = "List of supported hardware platforms";
      readOnly = true;
      default = {
        pi4 = "pi4";
        zero2 = "zero2";
        m1 = "m1";
        none = "none";
      };
    };

    hardwarePlatform = mkOption {
      type = types.enum (attrValues platforms);
      description = "Hardware platform to build for";
      default = "none";
    };
  };
}
