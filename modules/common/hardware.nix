{
  lib,
  options,
  config,
  ...
}:
with lib; let
  platform = config.settings.hardware;
  platforms = config.settings.hardwares;
in {
  options.settings = {
    hardwares = mkOption {
      type = types.attrsOf types.str;
      description = "List of supported hardware platforms";
      readOnly = true;
      default = {
        pi4 = "pi4";
        zero2 = "zero2";
        x86-hetzner = "x86-hetzner";
        none = "none";
      };
    };

    hardware = mkOption {
      type = types.enum (attrValues platforms);
      description = "Hardware platform to build for";
      default = "none";
    };
  };
}
