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
in {
  nixosModules.default = [
    home-manager.nixosModules.home-manager
    agenix.nixosModules.default
    ../modules/linux
    ../settings.nix
  ];

  darwinModules.default = [
    home-manager.darwinModules.home-manager
    agenix.darwinModules.default
    ../modules/darwin
    ../settings.nix
  ];

  nixosConfigurations = flake-lib.mkNixosConfigurations {
    mainPath = ../.;
    defaultModules = self.nixosModules.default;
    inherit flakeInputs nixpkgs;
  };

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
    # TODO Darwin deployment doesn't work as sudo prompts for a password
    nodes = let
      hostsPath = ../hosts;
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
}
