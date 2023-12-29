{
  description = "Nicos - Nix Integrated Configuration and Operational Systems";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";

    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable-small";

    nix-darwin.url = "github:lnl7/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    # ? how is it used?
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-23.05-darwin";

    srvos.url = "github:nix-community/srvos";
    srvos.inputs.nixpkgs.follows = "nixpkgs";

    nixos-anywhere.url = "github:nix-community/nixos-anywhere";
    nixos-anywhere.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    agenix.inputs.darwin.follows = "nixpkgs-darwin";
    agenix.inputs.home-manager.follows = "home-manager";

    impermanence.url = "github:nix-community/impermanence";

    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Used for building the documentation
    pnpm2nix.url = "github:nzbr/pnpm2nix-nzbr";
  };

  outputs = inputs @ {
    agenix,
    deploy-rs,
    flake-utils,
    home-manager,
    impermanence,
    nix-darwin,
    nixos-anywhere,
    nixpkgs,
    pnpm2nix,
    self,
    ...
  }: let
    inherit (nixpkgs) lib;
  in
    {
      lib = {configure = import ./configure.nix inputs;};
    }
    // flake-utils.lib.eachDefaultSystem
    (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      python = pkgs.python3;
    in rec {
      inherit (import ./modules inputs) nixosModules darwinModules;

      packages = {
        cli = python.pkgs.buildPythonApplication rec {
          name = "nicos";
          propagatedBuildInputs =
            [
              agenix.packages.${system}.default
              pkgs.wireguard-tools
              nixos-anywhere.packages.${system}.default
            ]
            ++ (with python.pkgs; [
              bcrypt
              python-box
              click
              cryptography
              inquirer
              jinja2
              psutil
            ]);
          src = ./cli;
        };

        docgen = pkgs.writeShellApplication {
          name = "docgen";
          text = let
            generateMdOptions = opt:
              if (opt ? "_type" && opt._type == "option")
              then [
                ''
                  ## ${(opt.__toString {})}
                  ${opt.description}
                ''
              ]
              else lib.flatten (lib.mapAttrsToList (_: generateMdOptions) opt);

            nixosSystem = nixpkgs.lib.nixosSystem {
              system = "aarch64-linux";
              modules = nixosModules.default;
            };

            # TODO generate Darwin documentation too
            darwinSystem = nix-darwin.lib.darwinSystem {
              system = "aarch64-darwin";
              modules = darwinModules.default;
            };
          in ''
            mkdir -p documentation
            cat << EOF > docs/options/nixos.mdx
            ${builtins.concatStringsSep "\n" (generateMdOptions nixosSystem.options.settings)}
            EOF
            cat << EOF > docs/options/darwin.mdx
            ${builtins.concatStringsSep "\n" (generateMdOptions darwinSystem.options.settings)}
            EOF

          '';
        };
      };

      apps = rec {
        default = cli;

        cli = flake-utils.lib.mkApp {drv = self.packages.${system}.cli;};
      };

      devShells = {
        default = pkgs.mkShell {
          # Load the dependencies of all the packages
          packages = lib.mapAttrsToList (name: pkg: pkg.propagatedBuildInputs) self.packages.${system};
          shellHook = ''
            # echo "Nix environment loaded"
          '';
        };
      };
    });
}
