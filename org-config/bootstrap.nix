{
  config,
  lib,
  pkgs,
  ...
}: {
  # TODO remove this eventually once the bluetooth/otg package is developped
  environment.etc."wifi.conf" = {
    source = /run/agenix/wifi-install;
    mode = "700";
  };

  networking = {
    interfaces."wlan0".useDHCP = true;
    wireless = {
      enable = true;
      environmentFile = "/etc/wifi.conf";
      interfaces = ["wlan0"];
      networks.mjmp.psk = "@PSK_HOME@";
    };
  };

  # ? Move elsewhere?
  # Enables `wpa_supplicant` on boot.
  systemd.services.wpa_supplicant.wantedBy = lib.mkOverride 10 ["default.target"];
}
