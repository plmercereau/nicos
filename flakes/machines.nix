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

  hostOverrides = { };
in
{
  nixosModules.default = [
    home-manager.nixosModules.home-manager
    agenix.nixosModules.default
    # TODO dig into this (ResilientOS)
    # ./flake-config.nix
    ../modules/common
    ../modules/linux
  ];

  darwinModules.default = [
    home-manager.darwinModules.home-manager
    agenix.darwinModules.default
    ../modules/common
    ../modules/darwin
  ];

  nixosConfigurations = flake-lib.mkNixosConfigurations {
    hostsPath = ../org-config/hosts/linux;
    nixpkgs = nixpkgs;
    defaultModules = self.nixosModules.default ++ [ ../org-config/linux.nix ];
    inherit flakeInputs hostOverrides;
  };

  darwinConfigurations = flake-lib.mkDarwinConfigurations
    {
      hostsPath = ../org-config/hosts/darwin;
      defaultModules = self.darwinModules.default ++ [ ../org-config/darwin.nix ];
      inherit nix-darwin flakeInputs hostOverrides;
    };

  packages.aarch64-linux = {
    pi4-installer = (nixpkgs.lib.nixosSystem {
      specialArgs = { flakeInputs = flakeInputs // { inherit nixpkgs; }; };
      modules = self.nixosModules.default ++ [
        ../modules/linux/sd-image
        ../org-config/bootstrap.nix
        ({ config, ... }:
          {
            settings.hardwarePlatform = config.settings.hardwarePlatforms.pi4;
            settings.profile = config.settings.profiles.minimal;
            settings.server.enable = true;
            sdImage.imageName = "nixos-sd-image-pi4.img";
          })
      ];
    }).config.system.build.sdImage;

    zero2-installer = (nixpkgs.lib.nixosSystem {
      specialArgs = { flakeInputs = flakeInputs // { inherit nixpkgs; }; };
      modules = self.nixosModules.default ++ [
        ../modules/linux/sd-image
        ../org-config/bootstrap.nix
        ({ config, ... }:
          {
            settings.hardwarePlatform = config.settings.hardwarePlatforms.zero2;
            settings.profile = config.settings.profiles.minimal;
            settings.server.enable = true;
            sdImage.imageName = "nixos-sd-image-zero2.img";
          })
      ];
    }).config.system.build.sdImage;
  };

}
    