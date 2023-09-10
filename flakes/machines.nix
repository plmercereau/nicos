flakeInputs @ {
  self,
  flake-utils,
  nixpkgs,
  agenix,
  home-manager,
  nix-darwin,
  nixpkgs-darwin,
  deploy-rs,
}: let
  # Get a lib instance that we use only in the scope of this flake.
  # The actual NixOS configs use their own instances of nixpkgs.
  inherit (nixpkgs) lib;

  flake-lib = import ../lib.nix {inherit lib;};

  hostOverrides = {};
in {
  nixosModules.default = [
    home-manager.nixosModules.home-manager
    agenix.nixosModules.default
    ../modules/linux
  ];

  darwinModules.default = [
    home-manager.darwinModules.home-manager
    agenix.darwinModules.default
    ../modules/darwin
  ];

  nixosConfigurations = flake-lib.mkNixosConfigurations {
    orgConfigPath = ../org-config;
    defaultModules = self.nixosModules.default;
    inherit flakeInputs hostOverrides nixpkgs;
  };

  darwinConfigurations =
    flake-lib.mkDarwinConfigurations
    {
      orgConfigPath = ../org-config;
      defaultModules = self.darwinModules.default;
      inherit flakeInputs hostOverrides nix-darwin;
    };

  # TODO map all the hosts from self.nixosConfigurations and self.darwinConfigurations
  # -> we also need to determine the system (e.g. aarch64-linux) for each host
  deploy.nodes.pi4g = {
    magicRollback = false; # TODO required to be false when changing network / hostname / users
    user = "root"; # Is this the refault already?
    sshOpts = ["-p" "22"];
    hostname = "pi4g";
    fastConnection = true;
    profiles.system = {
      # sshUser = "admin";
      path = deploy-rs.lib.aarch64-linux.activate.nixos self.nixosConfigurations.pi4g;
    };
  };

  packages.aarch64-linux = {
    pi4-installer =
      (nixpkgs.lib.nixosSystem {
        specialArgs = {flakeInputs = flakeInputs // {inherit nixpkgs;};};
        modules =
          self.nixosModules.default
          ++ [
            ../modules/linux/sd-image
            ../org-config/bootstrap
            ({config, ...}: {
              settings.hardwarePlatform = config.settings.hardwarePlatforms.pi4;
              settings.profile = config.settings.profiles.minimal;
              settings.server.enable = true;
              sdImage.imageName = "nixos-sd-image-pi4.img";
            })
          ];
      })
      .config
      .system
      .build
      .sdImage;

    zero2-installer =
      (nixpkgs.lib.nixosSystem {
        specialArgs = {flakeInputs = flakeInputs // {inherit nixpkgs;};};
        modules =
          self.nixosModules.default
          ++ [
            ../modules/linux/sd-image
            ../org-config/bootstrap
            ({config, ...}: {
              settings.hardwarePlatform = config.settings.hardwarePlatforms.zero2;
              settings.profile = config.settings.profiles.minimal;
              settings.server.enable = true;
              sdImage.imageName = "nixos-sd-image-zero2.img";
            })
          ];
      })
      .config
      .system
      .build
      .sdImage;
  };
}
