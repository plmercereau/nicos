{config, ...}: {
  imports = [../hardware/raspberry-pi-4.nix];
  settings.impermanence.enable = true;
}
