{
  config,
  pkgs,
  lib,
  ...
}: {
  age.secrets.wifi = {
    file = ../../secrets/wifi.age;
    group = "admin";
    mode = "740";
  };

  networking = {
    interfaces."wlan0".useDHCP = true;
    wireless = {
      enable = true;
      interfaces = ["wlan0"];
      environmentFile = config.age.secrets.wifi.path;
      networks.mjmp.psk = "@mjmp@";
    };
  };
}
