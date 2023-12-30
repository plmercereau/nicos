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
  inherit (import ../hardware inputs) nixosHardwareModules darwinHardwareModules;
  features = import ../features inputs;

  importModules = name:
    builtins.filter
    (path: let
      fileName = builtins.baseNameOf path;
      dirName = builtins.baseNameOf (builtins.dirOf path);
      isCorrectFileName = fileName == "${name}.nix";
      # also import "${name}/default.nix"
      isDefaultDirectory = (dirName == name) && (fileName == "default.nix");
    in (isCorrectFileName || isDefaultDirectory))
    (lib.filesystem.listFilesRecursive ./.);

  nixosModules =
    {
      default =
        [
          agenix.nixosModules.default
          disko.nixosModules.disko
          impermanence.nixosModules.impermanence
          home-manager.nixosModules.home-manager
          srvos.nixosModules.mixins-trusted-nix-caches
        ]
        ++ (features.modules features.nixos)
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
        ++ (features.modules features.darwin)
        ++ (importModules "common")
        ++ (importModules "darwin");
    }
    // darwinHardwareModules;
in {
  inherit nixosModules darwinModules;
}
