{
  description = "Flake for managing my machines";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";

    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nix-darwin.url = "github:lnl7/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    # ? how is it used?
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-23.05-darwin";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    agenix.inputs.darwin.follows = "nixpkgs-darwin";
    agenix.inputs.home-manager.follows = "home-manager";

    impermanence.url = "github:nix-community/impermanence";

    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    pnpm2nix.url = "github:nzbr/pnpm2nix-nzbr";
  };

  outputs = inputs @ {
    agenix,
    deploy-rs,
    flake-utils,
    home-manager,
    impermanence,
    nix-darwin,
    nixpkgs,
    pnpm2nix,
    self,
    ...
  }: let
    inherit (nixpkgs) lib;
    flake-lib = import ./lib.nix inputs;
  in
    {
      lib = {inherit (flake-lib) configure;};
    }
    // flake-utils.lib.eachDefaultSystem
    (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      python = pkgs.python3;
    in {
      inherit (flake-lib) nixosModules darwinModules;

      packages = {
        cli = python.pkgs.buildPythonApplication {
          name = "cli.py";
          # propagatedBuildInputs = [flask];
          nativeBuildInputs =
            [agenix.packages.${system}.default pkgs.wireguard-tools]
            ++ (with python.pkgs; [
              bcrypt
              cryptography
              fire
              inquirer
              jinja2
              psutil
            ]);
          src = ./cli;
        };

        docgen = let
          optionsDocumentationRootUrl = ""; # default: "https://github.com/NixOS/nixpkgs/blob/main";
          linuxSystem = nixpkgs.lib.nixosSystem {
            system = "aarch64-linux";
            modules = flake-lib.nixosModules.default;
          };

          # TODO generate Darwin documentation too
          darwinSystem = nix-darwin.lib.darwinSystem {
            system = "aarch64-darwin";
            modules = flake-lib.darwinModules.default;
          };

          optionsDrv =
            (pkgs.nixosOptionsDoc {
              inherit (linuxSystem) options;
              transformOptions = opt:
              # Filter only options starting with "settings."
                if (lib.hasPrefix "settings." opt.name)
                then
                  opt
                  // {
                    # Make declarations ("Declared by:") point to the source code, not to the nix store
                    # See: https://github.com/NixOS/nixpkgs/blob/26754f31fd74bf688a264e1156d36aa898311618/doc/default.nix#L71
                    declarations =
                      map
                      (decl:
                        if lib.hasPrefix (toString ../..) (toString decl)
                        then let
                          subpath = lib.removePrefix "/" (lib.removePrefix (toString ../.) (toString decl));
                        in {
                          url = "${optionsDocumentationRootUrl}/${subpath}";
                          name = subpath;
                        }
                        else decl)
                      opt.declarations;
                  }
                else {visible = false;};
            })
            .optionsJSON;
        in
          pkgs.writeShellApplication {
            name = "docgen";
            runtimeInputs = [pkgs.jq];
            text = "jq . < ${optionsDrv}/share/doc/nixos/options.json";
          };

        documentation = pnpm2nix.packages.${system}.mkPnpmPackage {
          src = ./documentation;
          nodejs = pkgs.nodejs;
          distDir = "build";
          pnpm = pkgs.nodejs.pkgs.pnpm;
          copyPnpmStore = false; # When true (default), an error is thrown
          extraBuildInputs = [self.packages.${system}.docgen];
          preBuild = ''
            ${self.packages.${system}.docgen}/bin/docgen > src/options.json
          '';
        };
      };

      apps = rec {
        default = cli;

        cli = flake-utils.lib.mkApp {drv = self.packages.${system}.cli;};

        docgen = flake-utils.lib.mkApp {
          drv = self.packages.${system}.docgen;
        };
      };

      devShells = {
        default = pkgs.mkShell {
          # Load the dependencies of all the packages
          packages = lib.mapAttrsToList (name: pkg: pkg.nativeBuildInputs) self.packages.${system};
          shellHook = ''
            # echo "Nix environment loaded"
          '';
        };
      };
    });
}
