{ lib, modulesPath, config, ... }:
with lib;
let
  profile = config.settings.profile;
  profiles = config.settings.profiles;
in
{
  config = mkIf (profile == profiles.minimal) (
    import (modulesPath + "/profiles/minimal.nix") { inherit config lib; }
    //
    import (modulesPath + "/profiles/headless.nix") { inherit config lib; }
  );
}
