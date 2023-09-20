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

  # Make all the NixOS and Darwin configurations deployable by deploy-rs
  deploy = {
    user = "root";
    # TODO Darwin deployment doesn't work as sudo prompts for a password
    nodes = let
      hostsPath = ../org-config/hosts;
      jsonFiles = builtins.attrNames (lib.filterAttrs (name: type: type == "regular" && (lib.hasSuffix ".json" name)) (builtins.readDir hostsPath));
    in
      builtins.listToAttrs (builtins.map (fileName: let
          name = lib.removeSuffix ".json" fileName;
          config = lib.importJSON "${hostsPath}/${fileName}";
          systemType =
            if (lib.hasSuffix "-darwin" config.platform)
            then "darwin"
            else "nixos";
          printHostname = lib.trace "Evaluating deployment: ${name} (${config.platform})";
        in {
          inherit name;
          value = printHostname {
            hostname = name;
            # ! workaround: do not build x86_64 machines locally as it is assumed the local builder is aarch64-darwin
            remoteBuild =
              lib.hasPrefix "x86_64" config.platform;
            profiles.system.path =
              deploy-rs.lib.${config.platform}.activate.${systemType} self."${systemType}Configurations"."${name}";
          };
        })
        jsonFiles);
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
              settings.hardware = config.settings.hardwares.pi4;
              nixpkgs.hostPlatform = "aaarch64-linux";
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
              nixpkgs.hostPlatform = "aaarch64-linux";
              settings.hardware = config.settings.hardwares.zero2;
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
