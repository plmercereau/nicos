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
  inherit (import ./hardware.nix inputs) nixosHardwareModules darwinHardwareModules;
  features = import ../features inputs;

  importModules = path: name: (builtins.filter
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
    (lib.filesystem.listFilesRecursive path));

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
        ++ (features.modules features.nixos)
        ++ (importModules ../modules "common")
        ++ (importModules ../modules "nixos");
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
        ++ (features.modules features.darwin)
        ++ (importModules ../modules "common")
        ++ (importModules ../modules "darwin");
    }
    // darwinHardwareModules;
in {
  inherit nixosModules darwinModules importModules;
}
