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
  modules = import ./lib/modules.nix inputs;
  inherit (modules) nixosModules darwinModules;

  hardware = import ./lib/hardware.nix inputs;
  inherit (hardware) nixosHardware nixosHardwareModules darwinHardware darwinHardwareModules;

  wifi = import ./lib/wifi.nix inputs;
  builders = import ./lib/builders.nix inputs;
  users = import ./lib/users.nix inputs;
  vpn = import ./lib/vpn.nix inputs;

  printMachine = name: builtins.trace "Evaluating machine: ${name}";

  hostsList = root: path:
    if (path == null)
    then []
    else
      lib.foldlAttrs
      (acc: name: type: acc ++ lib.optional (type == "regular" && lib.hasSuffix ".nix" name) (lib.removeSuffix ".nix" name))
      []
      (builtins.readDir (root + "/${path}"));

  configure = {
    projectRoot,
    clusterAdminKeys, # TODO check if not empty (otherwise, the cluster will be unusable) and if they are valid public keys (see modules/common/lib.nix#pub_key_type)
    nixosHostsPath,
    darwinHostsPath,
    builderPath,
    usersPath,
    wifiPath,
    extraModules ? [],
  } @ params: let
    nixosConfigurations = lib.genAttrs (hostsList projectRoot nixosHostsPath) (hostname:
      printMachine hostname nixpkgs.lib.nixosSystem {
        modules =
          nixosModules.default
          ++ [
            {
              inherit cluster; # load the information about the cluster (hosts, users, secrets, wifi)
              # Set the hostname from the file name
              networking.hostName = hostname;
            }
            (projectRoot + "/${nixosHostsPath}/${hostname}.nix")
            (wifi.wifiModule params)
            (builders.buildersModule params)
            (users.usersModule params)
            (vpn.vpnModule params nixosHostsPath)
          ]
          ++ extraModules;
        specialArgs = {
          hardware = nixosHardwareModules;
          srvos = srvos.nixosModules;
        };
      });

    darwinConfigurations = lib.genAttrs (hostsList projectRoot darwinHostsPath) (hostname:
      printMachine hostname nix-darwin.lib.darwinSystem {
        modules =
          darwinModules.default
          ++ [
            {
              inherit cluster; # load the information about the cluster (hosts, users, secrets, wifi)
              # Set the hostname from the file name # ? keep this, or add it to every .nix machine file?
              networking.hostName = hostname;
            }
            (projectRoot + "/${darwinHostsPath}/${hostname}.nix")
            (builders.buildersModule params)
            (users.usersModule params)
            (vpn.vpnModule params nixosHostsPath)
          ]
          ++ extraModules;
        specialArgs = {
          hardware = darwinHardwareModules;
        };
      });

    # Contains the configuration of all the machines in the cluster
    hostsConfig = lib.mapAttrs (_: sys: sys.config) (nixosConfigurations // darwinConfigurations);

    # Cluster object, that contains the cluster configuration
    cluster = {
      # ? projectRoot
      hosts = {
        config = hostsConfig;
        nixosPath = nixosHostsPath;
        darwinPath = darwinHostsPath;
      };
      secrets = {
        config = let
          vpnSecrets = vpn.vpnSecrets {
            inherit clusterAdminKeys nixosHostsPath darwinHostsPath hostsConfig;
          };
          usersSecrets = users.usersSecrets {
            inherit usersPath clusterAdminKeys hostsConfig;
          };
          wifiSecret = wifi.wifiSecret {
            inherit wifiPath clusterAdminKeys hostsConfig;
          };
          nixBuilderSecret = builders.nixBuilderSecret {
            inherit builderPath clusterAdminKeys;
          };
        in
          vpnSecrets // usersSecrets // wifiSecret // nixBuilderSecret;
        adminKeys = clusterAdminKeys;
      };
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
      hostsConfig;
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
