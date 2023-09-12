flakeInputs @ {
  self,
  flake-utils,
  nixpkgs,
  agenix,
  home-manager,
  nix-darwin,
  nixpkgs-darwin,
  deploy-rs,
}:
flake-utils.lib.eachDefaultSystem
(system: let
  # optionsDocumentationRootUrl = "https://github.com/NixOS/nixpkgs/blob/main";
  optionsDocumentationRootUrl = ".."; # Doc root is "./documentation"
  pkgs = nixpkgs.legacyPackages.${system};
  inherit (nixpkgs) lib;
in rec {
  apps = rec {
    default = repl;

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

  devShells.default = pkgs.mkShell {
    packages = with pkgs; [
      agenix.packages.${system}.default # agenix cli
      # ! just autocompletion is not enabled by the dev shell
      just
      nodejs # * used by documentation scripts
      nodePackages.pnpm # * used by documentation scripts
      nushell # * used by custom yabai scripts.
      copier # * used for templates
      # ! just autocompletion is not enabled by the dev shell
      go-task
    ];
    shellHook = ''
      echo "Nix environment loaded"
    '';
  };
})
