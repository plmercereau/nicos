inputs @ {
  agenix,
  deploy-rs,
  disko,
  home-manager,
  impermanence,
  nix-darwin,
  nixpkgs,
  srvos,
  ...
}: let
  inherit (nixpkgs) lib;
  inherit (import ./modules inputs) nixosModules darwinModules;
  inherit (import ./hardware inputs) nixosHardware nixosHardwareModules darwinHardware darwinHardwareModules;
  features = import ./features inputs;

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
  params @ {
    projectRoot,
    adminKeys,
    extraModules ? [],
    nixos ? {
      enable = false;
      path = null;
    },
    darwin ? {
      enable = false;
      path = null;
    },
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
      nixosConfigurations =
        lib.optionalAttrs nixos.enable
        (lib.genAttrs (hostsList projectRoot nixos.path) (hostname:
          printMachine hostname nixpkgs.lib.nixosSystem {
            modules =
              nixosModules.default
              ++ [
                (projectRoot + "/${nixos.path}/${hostname}.nix")
                {
                  # Set the hostname from the file name # ? keep this, or add it to every .nix machine file?
                  networking.hostName = hostname;
                }
              ]
              ++ extraModules;
            specialArgs = {
              inherit cluster;
              hardware = nixosHardwareModules;
              srvos = srvos.nixosModules;
            };
          }));

      darwinConfigurations = lib.optionalAttrs darwin.enable (lib.genAttrs (hostsList projectRoot darwin.path) (hostname:
        printMachine hostname nix-darwin.lib.darwinSystem {
          modules =
            darwinModules.default
            ++ [
              (projectRoot + "/${darwin.path}/${hostname}.nix")
              {
                # Set the hostname from the file name # ? keep this, or add it to every .nix machine file?
                networking.hostName = hostname;
              }
            ]
            ++ extraModules;
          specialArgs = {
            inherit cluster;
            hardware = darwinHardwareModules;
          };
        }));

      # Contains the configuration of all the machines in the cluster
      hosts = lib.mapAttrs (_: sys: sys.config) (nixosConfigurations // darwinConfigurations);

      # Cluster object, that contains the cluster configuration
      cluster = {
        inherit projectRoot nixos darwin builders users wifi hosts adminKeys;
        secrets = features.secrets (params // {inherit hosts;});
        hardware = {
          nixos = nixosHardware;
          darwin = darwinHardware;
        };

        # Returns a simplified tree of all the options of the modules (except the ones potentially defined in the machine files)
        options = let
          nixosSystem = nixpkgs.lib.nixosSystem {
            modules = [{nixpkgs.hostPlatform = "aarch64-linux";}] ++ nixosModules.default ++ extraModules;
            specialArgs = {
              inherit cluster;
              hardware = nixosHardwareModules;
            };
          };
          darwinSystem = nix-darwin.lib.darwinSystem {
            modules = [{nixpkgs.hostPlatform = "aarch64-darwin";}] ++ darwinModules.default ++ extraModules;
            specialArgs = {
              inherit cluster;
              hardware = darwinHardwareModules;
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
        in {
          nixos = simplifyOptions nixosSystem;
          darwin = simplifyOptions darwinSystem;
        };
      };

      # Make all the NixOS and Darwin configurations deployable by deploy-rs
      deploy = {
        user = "root";
        nodes = builtins.mapAttrs (hostname: config: let
          inherit (config.nixpkgs) hostPlatform;
          printHostname = builtins.trace "Evaluating deployment: ${hostname} (${hostPlatform.system})";
          path =
            if (hostPlatform.isDarwin)
            then deploy-rs.lib.${hostPlatform.system}.activate.darwin darwinConfigurations.${hostname}
            else deploy-rs.lib.${hostPlatform.system}.activate.nixos nixosConfigurations.${hostname};
          # TODO workaround to be able to use sudo with darwin.
          # * See: https://github.com/serokell/deploy-rs/issues/78
          optionalSshOpts = lib.optional (hostPlatform.isDarwin) "-t";
        in
          printHostname {
            inherit hostname;
            # Workaround to be able to use sudo with darwin. See the above mentionned issue.
            magicRollback = !hostPlatform.isDarwin;

            profiles = let
              inherit (config.settings) networking;
            in {
              system = {
                inherit path;
                sshOpts = let
                  domain =
                    if (networking.vpn.enable)
                    then networking.vpn.domain
                    else if (networking.publicIP != null)
                    then "public"
                    else if (networking.localIP != null)
                    then "local"
                    else null;
                in
                  optionalSshOpts ++ lib.optionals (domain != null) ["-o" "HostName=${hostname}.${domain}"];
              };
              lan = {
                inherit path;
                sshOpts = optionalSshOpts ++ ["-o" "HostName=${networking.localIP}"];
              };
              public = {
                inherit path;
                sshOpts = optionalSshOpts ++ ["-o" "HostName=${networking.publicIP}"];
              };
              vpn = {
                inherit path;
                sshOpts = optionalSshOpts ++ ["-o" "HostName=${config.lib.vpn.ip}"];
              };
            };
          })
        hosts;
      };
    in
      lib.recursiveUpdate {
        inherit
          nixosConfigurations
          darwinConfigurations
          deploy
          cluster
          ;
      }
