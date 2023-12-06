flakeInputs @ {
  self,
  nixpkgs,
  nix-darwin,
  agenix,
  impermanence,
  home-manager,
  deploy-rs,
  ...
}: let
  # Get a lib instance that we use only in the scope of this flake.
  # The actual NixOS configs use their own instances of nixpkgs.
  inherit (nixpkgs) lib;

  flake-lib = import ../lib.nix {inherit lib;};
in {
  nixosModules.default = [
    agenix.nixosModules.default
    impermanence.nixosModules.impermanence
    home-manager.nixosModules.home-manager
    ../modules/linux
    ../settings.nix
  ];

  darwinModules.default = [
    agenix.darwinModules.default
    home-manager.darwinModules.home-manager
    ../modules/darwin
    ../settings.nix
  ];

  nixosConfigurations = flake-lib.mkNixosConfigurations {
    mainPath = ../.;
    defaultModules = self.nixosModules.default;
    inherit flakeInputs nixpkgs;
  };
  # // {
  #   # TODO what's the best way to cross compile? And how to make sure it compiles regardless of the builder architecture?
  #   # # * nix build .#nixosConfigurations.livecd.config.system.build.isoImage --no-link --print-out-paths
  #   livecd = nixpkgs.lib.nixosSystem {
  #     # ! 1
  #     # system = "aarch64-linux";

  #     modules = [
  #       {
  #         # ! 1
  #         # nixpkgs.crossSystem.system = "x86_64-linux";

  #         # ! 2
  #         nixpkgs.hostPlatform.system = "x86_64-linux"; # target platform
  #         nixpkgs.buildPlatform.system = "aarch64-linux"; # platform of the builder

  #         # ! 3 binfmt QEMU
  #         boot.binfmt.emulatedSystems = ["x86_64-linux"];
  #       }
  #       "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
  #     ];
  #   };
  # };

  darwinConfigurations =
    flake-lib.mkDarwinConfigurations
    {
      mainPath = ../.;
      defaultModules = self.darwinModules.default;
      inherit flakeInputs nix-darwin;
    };

  # Make all the NixOS and Darwin configurations deployable by deploy-rs
  deploy = {
    user = "root";
    nodes = builtins.mapAttrs (hostname: config: let
      systemType =
        if (lib.hasSuffix "-darwin" config.platform)
        then "darwin"
        else "nixos";
      printHostname = lib.trace "Evaluating deployment: ${hostname} (${config.platform})";
    in
      printHostname ({
          inherit hostname;
          # TODO workaround: do not build x86_64 machines locally as it is assumed the local builder is aarch64-darwin
          remoteBuild =
            lib.hasPrefix "x86_64" config.platform;
          profiles.system.path =
            deploy-rs.lib.${config.platform}.activate.${systemType} self."${systemType}Configurations"."${hostname}";
        }
        //
        # TODO workaround to be able to use sudo with darwin.
        # * See: https://github.com/serokell/deploy-rs/issues/78
        lib.optionalAttrs (systemType == "darwin") {
          magicRollback = true;
          sshOpts = ["-t"];
        }))
    (flake-lib.loadHostsConfig ../hosts);
  };
}
