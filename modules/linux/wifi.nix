{
  config,
  lib,
  orgConfigPath,
  ...
}: let
  networks = lib.importJSON "${orgConfigPath}/wifi/list.json";
in {
  config = {
    # TODO check if list.json and psk.age exists. If not, create a warning instead of an error
    # Only mount wifi passwords if wireless is enabled
    age.secrets.wifi = lib.mkIf config.networking.wireless.enable {
      file = builtins.toPath "${orgConfigPath}/wifi/psk.age";
      group = "wheel";
      mode = "740";
    };

    # Only configure default wifi if wireless is enabled
    networking = lib.mkIf config.networking.wireless.enable {
      interfaces."wlan0".useDHCP = true;
      wireless = {
        interfaces = ["wlan0"];
        environmentFile = config.age.secrets.wifi.path;
        networks = builtins.listToAttrs (builtins.map (name: {
            inherit name;
            value = {psk = "@${name}@";};
          })
          networks);
      };
    };
  };
}
