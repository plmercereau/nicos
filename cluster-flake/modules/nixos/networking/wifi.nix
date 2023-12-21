{
  config,
  lib,
  ...
}: {
  # Enables `wpa_supplicant` on boot.
  systemd.services.wpa_supplicant.wantedBy = lib.mkIf config.networking.wireless.enable (lib.mkOverride 10 ["default.target"]);
}
