{config, ...}: {
  imports = [./bastion.nix ./client.nix];

  # ! don't let the networkmanager manage the vpn interface for now as it conflicts with resolved
  networking.networkmanager.unmanaged = [config.settings.networking.vpn.interface];
}
