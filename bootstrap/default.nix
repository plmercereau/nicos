{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (config.lib) ext_lib;
in {
  settings.profile = config.settings.profiles.minimal;
  settings.server.enable = true;

  users.users.nixos.openssh.authorizedKeys.keys = ext_lib.mkAdminsKeysList ../users;

  home-manager.users.nixos.home = {
    stateVersion = "23.05";
    file.".zshrc".text = "";
  };

  # TODO remove this eventually once the bluetooth/otg package is developped
  # ! Manually mount the /run/wifi-install file
  # ! agenix is not happy with "./folder/secret.age" in secrets.nix then age.secrets.secret.file = ../folder/secret.age (./ and ../ differ)
  # environment.etc."wifi.conf" = {
  #   source = /run/wifi-install;
  #   mode = "700";
  # };

  # networking = {
  #   interfaces."wlan0".useDHCP = true;
  #   wireless = {
  #     enable = true;
  #     environmentFile = "/etc/wifi.conf";
  #     interfaces = ["wlan0"];
  #     networks.mjmp.psk = "@PSK_HOME@";
  #   };
  # };

  # ? Move elsewhere?
  # Enables `wpa_supplicant` on boot.
  systemd.services.wpa_supplicant.wantedBy = lib.mkOverride 10 ["default.target"];
}
