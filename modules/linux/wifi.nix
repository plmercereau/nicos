{
  config,
  lib,
  ...
}: {
  # TODO check if list.json and psk.age exists. If not, create a warning instead of an error
  # Only mount wifi passwords if wireless is enabled
  age.secrets.wifi = lib.mkIf config.networking.wireless.enable {
    file = ../../wifi/psk.age;
    symlink = false;
  };

  # Only configure default wifi if wireless is enabled
  networking = lib.mkIf config.networking.wireless.enable {
    interfaces."wlan0".useDHCP = true;
    wireless = {
      interfaces = ["wlan0"];
      environmentFile = config.age.secrets.wifi.path;
      networks = let
        list = lib.importJSON ../../wifi/list.json;
      in
        builtins.listToAttrs (builtins.map (name: {
            inherit name;
            value = {psk = "@${name}@";};
          })
          list);
    };
  };

  # Enables `wpa_supplicant` on boot.
  systemd.services.wpa_supplicant.wantedBy = lib.mkIf config.networking.wireless.enable (lib.mkOverride 10 ["default.target"]);
}
