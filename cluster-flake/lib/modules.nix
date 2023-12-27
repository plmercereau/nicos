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
  hardware = import ./hardware.nix inputs;
  inherit (hardware) nixosHardwareModules darwinHardwareModules;

  importModules = name: (builtins.filter
    # TODO improve: filter out directories
    (path: let
      fileName = builtins.baseNameOf path;
      dirName = builtins.baseNameOf (builtins.dirOf path);
    in (
      (fileName == "${name}.nix")
      || (
        # also import "${name}/default.nix"
        (fileName == "default.nix") && (dirName == name)
      )
    ))
    (lib.filesystem.listFilesRecursive ../modules));

  nixosModules =
    {
      default =
        [
          agenix.nixosModules.default
          disko.nixosModules.disko
          impermanence.nixosModules.impermanence
          home-manager.nixosModules.home-manager
          srvos.nixosModules.mixins-trusted-nix-caches
          # TODO check srvos.nixosModules.common
        ]
        ++ (importModules "common")
        ++ (importModules "nixos");
    }
    // nixosHardwareModules;

  darwinModules =
    {
      default =
        [
          agenix.darwinModules.default
          home-manager.darwinModules.home-manager
          srvos.nixosModules.mixins-trusted-nix-caches
        ]
        ++ (importModules "common")
        ++ (importModules "darwin");
    }
    // darwinHardwareModules;
in {
  inherit nixosModules darwinModules;
}
