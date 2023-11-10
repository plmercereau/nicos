{config, ...}: {
  imports = [../hardware/hetzner-x86.nix];
  settings.server.enable = true;
}
