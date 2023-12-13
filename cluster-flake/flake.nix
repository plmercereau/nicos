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
  };

  outputs = inputs @ {
    self,
    flake-utils,
    nixpkgs,
    agenix,
    nix-darwin,
    impermanence,
    home-manager,
    deploy-rs,
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
    in rec {
      inherit (flake-lib) nixosModules darwinModules;

      packages = {
        cli = python.pkgs.buildPythonApplication {
          name = "cli.py";
          # propagatedBuildInputs = [flask];
          buildInputs =
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
      };

      apps = rec {
        default = cli;

        cli = flake-utils.lib.mkApp {drv = packages.cli;};

        # Browse the flake using nix repl
        repl = flake-utils.lib.mkApp {
          drv = pkgs.writeShellScriptBin "repl" ''
            confnix=$(mktemp)
            echo "builtins.getFlake (toString $(git rev-parse --show-toplevel))" >$confnix
            trap "rm $confnix" EXIT
            nix repl $confnix
          '';
        };

        docgen = let
          # optionsDocumentationRootUrl = "https://github.com/NixOS/nixpkgs/blob/main";
          optionsDocumentationRootUrl = "."; # Doc root is "./documentation"
          # TODO generate Darwin documentation too
          linuxSystem = nixpkgs.lib.nixosSystem {
            system = "aarch64-linux";
            modules = self.nixosModules.default;
          };
          optionsDoc = pkgs.nixosOptionsDoc {
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
          };
        in
          flake-utils.lib.mkApp {
            drv = pkgs.writeShellScriptBin "docgen" ''
              mkdir -p documentation/src
              cat ${optionsDoc.optionsJSON}/share/doc/nixos/options.json | python -m json.tool > documentation/src/options.json
            '';
          };
      };

      devShells = {
        default = pkgs.mkShell {
          packages = with pkgs;
            [
              nodejs # used by documentation scripts # TODO move to documentation builder
              nodePackages.pnpm # used by documentation scripts # TODO move to documentation builder
              python3 # * python is used for developping the CLI
            ]
            ++ packages.cli.buildInputs;
          shellHook = ''
            echo "Nix environment loaded"
          '';
        };
      };
    });
}
