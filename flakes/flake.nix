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
    # optionsDocumentationRootUrl = "https://github.com/NixOS/nixpkgs/blob/main";
    optionsDocumentationRootUrl = "."; # Doc root is "./documentation"
    inherit (nixpkgs) lib;
    flake-lib = import ./lib.nix inputs;
  in
    {
      lib = {
        configure = config:
          lib.recursiveUpdate {
            inherit
              (flake-lib.mkConfigurations config)
              nixosConfigurations
              darwinConfigurations
              deploy
              cluster
              ;
          };
      };
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
            [agenix.packages.${system}.default]
            ++ (with pkgs; [wireguard-tools])
            ++ (with python.pkgs; [fire bcrypt]);
          src = ./src;
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

        agenix = flake-utils.lib.mkApp {
          drv = packages.agenix;
        };

        docgen = let
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
          packages = with pkgs; [
            # * The following packages are used for developping the documentation
            nodejs # used by documentation scripts # TODO add to documentation builder
            nodePackages.pnpm # used by documentation scripts # TODO add to documentation builder

            # * The following packages are used for developping the CLI
            agenix.packages.${system}.default
            wireguard-tools
            python3
            python3Packages.fire
            python3Packages.bcrypt

            # TODO remove or move to ../flake.nix devshell
            nushell # used by scripts # TODO remove
            go-task # no autocomplete # TODO move to ../flake.nix devshell
            openssl # Required to change password # TODO remove
          ];
          shellHook = ''
            echo "Nix environment loaded"
          '';
        };
      };
    });
}
