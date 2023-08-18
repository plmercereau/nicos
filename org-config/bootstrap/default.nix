{ config, lib, pkgs, ... }:
{
  # TODO remove this eventually once the bluetooth/otg package is developped
  environment.etc."wifi.conf" = {
    source = /run/agenix/wifi-install;
    mode = "700";
  };

  # The installer starts with a "nixos" user to allow installation, so add the SSH key to that user.
  # settings.users.users.nixos = {
  #   enable = true;
  #   public_keys = config.settings.users.users.pilou.public_keys;
  # };

  networking = {
    interfaces."wlan0".useDHCP = true;
    wireless = {
      enable = true;
      environmentFile = "/etc/wifi.conf";
      interfaces = [ "wlan0" ];
      networks.mjmp.psk = "@PSK_HOME@";
    };
  };

  # ? Move elsewhere?
  # Enables `wpa_supplicant` on boot.
  systemd.services.wpa_supplicant.wantedBy = lib.mkOverride 10 [ "default.target" ];


}
