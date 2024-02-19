inputs @ {
  agenix,
  deploy-rs,
  disko,
  home-manager,
  impermanence,
  nixpkgs,
  srvos,
  ...
}: let
  inherit (nixpkgs) lib;
  hardware = import ./hardware;
  features = import ./features inputs;

  nixosModules =
    [
      agenix.nixosModules.default
      disko.nixosModules.disko
      impermanence.nixosModules.impermanence
      home-manager.nixosModules.home-manager
      # TODO create a "srvos" special argument, then import srvos.nixosModules.mixins-trusted-nix-caches from nicos modules
      srvos.nixosModules.mixins-trusted-nix-caches
      ./modules
    ]
    ++ (features.modules);

  printMachine = name: lib.traceIf (builtins.getEnv "VERBOSE" == "1") "Evaluating machine: ${name}";

  hostsList = root: path:
    if (path == null)
    then []
    else
      lib.foldlAttrs
      (acc: name: type: acc ++ lib.optional (type == "regular" && lib.hasSuffix ".nix" name) (lib.removeSuffix ".nix" name))
      []
      (builtins.readDir (root + "/${path}"));
in
  {
    projectRoot,
    adminKeys,
    extraModules ? [],
    machinesPath,
    builders ? {
      enable = false;
      path = null;
    },
    users ? {
      enable = false;
      path = null;
    },
    wifi ? {
      enable = false;
      path = null;
    },
  }:
    if (builtins.length adminKeys == 0)
    then (throw "There should be at least one admin key in order to safely generate secrets")
    else let
      nixosConfigurations = lib.genAttrs (hostsList projectRoot machinesPath) (hostname:
        printMachine hostname nixpkgs.lib.nixosSystem {
          modules =
            nixosModules
            ++ [
              (projectRoot + "/${machinesPath}/${hostname}.nix")
              {
                # Set the hostname from the file name # ? keep this, or add it to every .nix machine file?
                networking.hostName = hostname;
              }
            ]
            ++ extraModules;
          specialArgs = {
            inherit cluster;
            hardware = hardware.modules;
            srvos = srvos.nixosModules;
          };
        });

      # TODO helper to get the config. Remove this if possible
      hosts =
        lib.mapAttrs (name: sys: sys.config)
        nixosConfigurations;

      # Cluster object, that contains the cluster configuration
      cluster = {
        inherit projectRoot machinesPath builders users wifi hosts adminKeys;
        secrets =
          features.secrets {inherit projectRoot machinesPath builders users wifi hosts adminKeys;}
          # * Optionally loads the secrets.nix file in the project root file if it exists
          // lib.optionalAttrs (builtins.pathExists (projectRoot + "/secrets.nix")) (import (projectRoot + "/secrets.nix"));
        hardware = hardware.recap;

        # Returns a simplified tree of all the options of the modules (except the ones potentially defined in the machine files)
        options = let
          nixosSystem = nixpkgs.lib.nixosSystem {
            modules = [{nixpkgs.hostPlatform = "aarch64-linux";}] ++ nixosModules ++ extraModules;
            specialArgs = {
              inherit cluster;
              hardware = hardware.modules;
            };
          };
          simplifyOptions = system:
            lib.filterAttrsRecursive (n: v: v != null) # Filter out null (internal) values
            
            (lib.mapAttrsRecursiveCond
              (as: !(as ? "_type" && as._type == "option"))
              (
                _: value:
                  if (value ? "internal" && value.internal)
                  then null # Don't include nor evaluate internal options
                  else
                    {
                      path = value.__toString {};
                      inherit (value) options isDefined;
                      description = lib.attrByPath ["description"] null value;
                      type = {
                        inherit (value.type) name;
                      };
                    }
                    // (let
                      eval = builtins.tryEval (value.value);
                    in
                      lib.optionalAttrs (eval.success) {inherit (eval) value;})
                    // lib.optionalAttrs (value ? "default") {inherit (value) default;}
              )
              system.options);
        in
          simplifyOptions nixosSystem;
      };

      # Make all the NixOS configurations deployable by deploy-rs
      deploy = {
        user = "root";
        nodes = builtins.mapAttrs (hostname: config: let
          inherit (config.nixpkgs) hostPlatform;
          printHostname = builtins.trace "Evaluating deployment: ${hostname} (${hostPlatform.system})";
          path = deploy-rs.lib.${hostPlatform.system}.activate.nixos nixosConfigurations.${hostname};
        in
          printHostname {
            inherit hostname;
            magicRollback = true;

            profiles = let
              inherit (config.settings) networking;
            in {
              system = {
                inherit path;
                sshOpts =
                  if config.settings.networking.vpn.enable
                  then ["-o" "HostName=${config.lib.vpn.ip}"]
                  else if (config.settings.networking.publicIP != null)
                  then ["-o" "HostName=${config.settings.networking.publicIP}"]
                  else if (config.settings.networking.localIP != null)
                  then ["-o" "HostName=${config.settings.networking.localIP}"]
                  else [];
              };
            };
          })
        hosts;
      };
    in
      lib.recursiveUpdate {
        inherit
          nixosConfigurations
          deploy
          cluster
          ;
      }
