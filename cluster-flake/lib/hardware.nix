inputs @ {
  agenix,
  deploy-rs,
  disko,
  home-manager,
  impermanence,
  nix-darwin,
  nixpkgs,
  srvos,
  ...
}: let
  inherit (nixpkgs) lib;

  nixosHardware = import ../hardware/nixos;
  darwinHardware = import ../hardware/darwin;

  importHardware = lib.mapAttrs (_: config: import config.path);

  nixosHardwareModules = importHardware nixosHardware;
  darwinHardwareModules = importHardware darwinHardware;
in {
  inherit nixosHardware nixosHardwareModules darwinHardware darwinHardwareModules importHardware;
}
