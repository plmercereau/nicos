{
  lib,
  options,
  config,
  ...
}:
with lib; let
  profile = config.settings.profile;
  profiles = config.settings.profiles;
in {
  options.settings = {
    profiles = mkOption {
      type = types.attrsOf types.str;
      description = "List of supported machine profiles. For the moment, only 'basic' and 'minimal' are supported.";
      readOnly = true;
      default = {
        minimal = "minimal";
        basic = "basic";
      };
    };

    profile = mkOption {
      type = types.enum (attrValues profiles);
      description = "Profile of the machine";
      default = profiles.basic;
    };
  };
}
