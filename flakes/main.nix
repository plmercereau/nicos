{
  self,
  flake-utils,
  nixpkgs,
  agenix,
  nix-darwin,
  impermanence,
  home-manager,
  deploy-rs,
  ...
}:
flake-utils.lib.eachDefaultSystem
(system: let
  # optionsDocumentationRootUrl = "https://github.com/NixOS/nixpkgs/blob/main";
  optionsDocumentationRootUrl = ".."; # Doc root is "./documentation"
  pkgs = nixpkgs.legacyPackages.${system};
  inherit (nixpkgs) lib;
  flake-lib = import ./lib.nix {inherit lib nixpkgs nix-darwin agenix impermanence home-manager deploy-rs;};
in rec {
  packages = {
    agenix = let
      # TODO: if we merge main.nix and machines.nix, we could use the following:
      # inherit (self) cluster users;
      inherit
        (flake-lib.mkConfigurations {
          projectRoot = ../.;
          nixosHostsPath = "./hosts-nixos";
          darwinHostsPath = "./hosts-darwin";
          usersPath = "./users";
          extraModules = [../settings.nix];
        })
        cluster
        users
        ;
      nixRules = flake-lib.mkSecretsKeys {
        inherit cluster users;
        wifiPath = "./wifi/psk.age"; # TODO
        clusterAdmins = ["pilou"];
      };
      rules = "builtins.fromJSON ''${builtins.toJSON nixRules}''";
    in
      # TODO improvement: accept secrets.nix or a RULES env var passed on by the user
      pkgs.writeShellScriptBin "agenix" ''
        export RULES=$(mktemp)
        trap "rm -f $RULES" EXIT
        cat <<EOF > $RULES
        ${rules}
        EOF
        ${agenix.packages.${system}.default}/bin/agenix $@
      '';
  };

  apps = rec {
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

  devShells.default = pkgs.mkShell {
    packages = with pkgs; [
      # agenix.packages.${system}.default # * agenix cli
      wireguard-tools
      nodejs # * used by documentation scripts
      nodePackages.pnpm # * used by documentation scripts
      nushell # * used by scripts
      go-task # * no autocomplete
      openssl # * Required to change password
    ];
    shellHook = ''
      echo "Nix environment loaded"
    '';
  };
})
