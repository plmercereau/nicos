{config, ...}: {
  imports = [../hardware/pi4.nix];
  settings.server.enable = true;

  # services.adguardhome.enable = true;
  # services.adguardhome.mutableSettings = false;
}
