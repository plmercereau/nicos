flakeInputs @ { self
, flake-utils
, nixpkgs
, agenix
, home-manager
, nix-darwin
, nixpkgs-darwin
}:
let
  # Get a lib instance that we use only in the scope of this flake.
  # The actual NixOS configs use their own instances of nixpkgs.
  inherit (nixpkgs) lib;

  flake-lib = import ../lib.nix { inherit lib; };

  commonModules = [
    ../modules/common
    ../org-config
  ];

  hostOverrides = { };
in
{
  nixosModules.default = [
    home-manager.nixosModules.home-manager
    agenix.nixosModules.default
    # TODO dig into this (ResilientOS)
    # ./flake-config.nix
    ../modules/linux
  ] ++ commonModules;

  darwinModules.default = [
    home-manager.darwinModules.home-manager
    agenix.darwinModules.default
    ../modules/darwin
  ] ++ commonModules;

  nixosConfigurations = flake-lib.mkNixosConfigurations {
    hostsPath = ../org-config/hosts/linux;
    nixpkgs = nixpkgs;
    defaultModules = self.nixosModules.default;
    inherit flakeInputs hostOverrides;
  };

  darwinConfigurations = flake-lib.mkDarwinConfigurations
    {
      hostsPath = ../org-config/hosts/darwin;
      defaultModules = self.darwinModules.default;
      inherit nix-darwin flakeInputs hostOverrides;
    };

  packages.aarch64-linux = {
    pi4-installer = (self.nixosConfigurations.pi4-installer.extendModules {
      modules = [
        ../modules/linux/sd-image
        ../org-config/bootstrap
      ];
    }).config.system.build.sdImage;
    zero2-installer = (self.nixosConfigurations.zero2-installer.extendModules {
      modules = [
        ../modules/linux/sd-image
        ../org-config/bootstrap
      ];
    }).config.system.build.sdImage;
  };

}
    