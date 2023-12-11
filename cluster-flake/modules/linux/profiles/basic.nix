{
  lib,
  modulesPath,
  config,
  ...
}:
with lib; let
  profile = config.settings.profile;
  profiles = config.settings.profiles;
in {
  config = mkIf (profile == profiles.basic) (
    {}
    // import (modulesPath + "/profiles/all-hardware.nix") {inherit config lib;}
    // import (modulesPath + "/profiles/base.nix") {inherit config lib;}
  );
}
