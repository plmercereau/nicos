{config, ...}: {
  imports = [../hardware/pi4.nix];

  # services.adguardhome.enable = true;
  # services.adguardhome.mutableSettings = false;
}
