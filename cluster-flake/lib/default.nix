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
  inherit (import ./modules.nix inputs) nixosModules darwinModules;
  inherit (import ./hardware.nix inputs) nixosHardware nixosHardwareModules darwinHardware darwinHardwareModules;
  features = import ../features inputs;

  printMachine = name: builtins.trace "Evaluating machine: ${name}";

  hostsList = root: path:
    if (path == null)
    then []
    else
      lib.foldlAttrs
      (acc: name: type: acc ++ lib.optional (type == "regular" && lib.hasSuffix ".nix" name) (lib.removeSuffix ".nix" name))
      []
      (builtins.readDir (root + "/${path}"));

  configure = params @ {
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
            magicRollback = !hostPlatform.isDarwin;
            profiles = let
              inherit (config.settings) networking;
            in {
              system = {
                inherit path;
                sshOpts = ["-o" "HostName=${networking.vpn.ip}"] ++ optionalSshOpts;
              };
              lan = {
                inherit path;
                sshOpts = ["-o" "HostName=${networking.localIP}"] ++ optionalSshOpts;
              };
              public = {
                inherit path;
                sshOpts = ["-o" "HostName=${networking.publicIP}"] ++ optionalSshOpts;
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
      };
in {
  inherit
    configure
    nixosModules
    darwinModules
    ;
}
