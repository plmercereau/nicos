{
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

  flake-lib = import ./lib.nix {inherit lib nixpkgs nix-darwin agenix impermanence home-manager deploy-rs;};
in {
  inherit (flake-lib) nixosModules darwinModules;

  lib = {
    inherit (flake-lib) mkConfigurations;
  };

  # ! This is user-defined
  inherit
    (flake-lib.mkConfigurations {
      projectRoot = ../.;
      usersPath = "./users";
      nixosHostsPath = "./hosts-nixos";
      darwinHostsPath = "./hosts-darwin";
      extraModules = [../settings.nix];
    })
    nixosConfigurations
    darwinConfigurations
    deploy
    cluster
    users
    ;

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
}
