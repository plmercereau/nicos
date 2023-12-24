{
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

  printMachine = name: builtins.trace "Evaluating machine: ${name}";

  # Get only the "<key-type> <key-value>" part of a public key (trim the potential comment e.g. user@host)
  trimPublicKey = key: let
    split = lib.splitString " " key;
  in "${builtins.elemAt split 0} ${builtins.elemAt split 1}";

  nixosHardware = import ./hardware/nixos;
  darwinHardware = import ./hardware/darwin;

  importModules = name: (builtins.filter
    # TODO improve: filter out directories
    (path: let
      fileName = builtins.baseNameOf path;
      dirName = builtins.baseNameOf (builtins.dirOf path);
    in (
      (fileName == "${name}.nix")
      || (
        # also import "${name}/default.nix"
        (fileName == "default.nix") && (dirName == name)
      )
    ))
    (lib.filesystem.listFilesRecursive ./modules));

  importHardware = lib.mapAttrs (_: config: import config.path);

  nixosModules =
    {
      default =
        [
          agenix.nixosModules.default
          disko.nixosModules.disko
          impermanence.nixosModules.impermanence
          home-manager.nixosModules.home-manager
          srvos.nixosModules.mixins-trusted-nix-caches
          # TODO check out srvos.nixosModules.common)
        ]
        ++ (importModules "common")
        ++ (importModules "nixos");
    }
    // importHardware nixosHardware;

  darwinModules =
    {
      default =
        [
          agenix.darwinModules.default
          home-manager.darwinModules.home-manager
          srvos.nixosModules.mixins-trusted-nix-caches
        ]
        ++ (importModules "common")
        ++ (importModules "darwin");
    }
    // importHardware darwinHardware;

  configure = {
    projectRoot,
    clusterAdminKeys, # TODO check if not empty (otherwise, the cluster will be unusable) and if they are valid public keys (see modules/common/lib.nix#pub_key_type)
    nixosHostsPath ? null,
    darwinHostsPath ? null,
    usersPath ? null,
    wifiPath ? null,
    extraModules ? [],
  }: let
    hostsList = path:
      if (path == null)
      then []
      else
        lib.foldlAttrs
        (acc: name: type: acc ++ lib.optional (type == "regular" && lib.hasSuffix ".nix" name) (lib.removeSuffix ".nix" name))
        []
        (builtins.readDir (projectRoot + "/${path}"));

    clusterConfigModule = {config, ...}: {
      inherit cluster; # load the information about the cluster (hosts, users, secrets, wifi)

      # Load user passwords
      age.secrets =
        lib.mkIf
        (usersPath != null)
        (
          lib.foldlAttrs
          (
            acc: name: config: let
              path = projectRoot + "/${usersPath}/${name}.hash.age";
            in
              acc // lib.optionalAttrs (builtins.pathExists path) {"password_${name}".file = path;}
          )
          {}
          config.users.users
        );
    };

    hostModules = hostsPath: hostname: [
      (projectRoot + "/${hostsPath}/${hostname}.nix")
      {
        # Set the hostname from the file name # ? keep this, or add it to every .nix machine file?
        networking.hostName = hostname;
        # Load wireguard private key
        age.secrets.wireguard.file = projectRoot + "/${hostsPath}/${hostname}.wg.age";
      }
    ];

    nixosConfigurations = lib.genAttrs (hostsList nixosHostsPath) (hostname:
      printMachine hostname nixpkgs.lib.nixosSystem {
        modules =
          nixosModules.default
          ++ [clusterConfigModule]
          ++ (hostModules nixosHostsPath hostname)
          ++ extraModules
          ++ [
            ({config, ...}: {
              # Load wifi PSKs
              # Only mount wifi passwords if wireless is enabled
              age.secrets.wifi = lib.mkIf (wifiPath != null && config.networking.wireless.enable) {
                file = projectRoot + "/${wifiPath}/psk.age";
              };

              # ? check if list.json and psk.age exists. If not, create a warning instead of an error?
              # Only configure default wifi if wireless is enabled
              networking = lib.mkIf (wifiPath != null && config.networking.wireless.enable) {
                wireless = {
                  environmentFile = config.age.secrets.wifi.path;
                  networks = let
                    list = lib.importJSON (projectRoot + "/${wifiPath}/list.json");
                  in
                    builtins.listToAttrs (builtins.map (name: {
                        inherit name;
                        value = {psk = "@${name}@";};
                      })
                      list);
                };
              };
            })
          ];
        specialArgs = {
          hardware = importHardware nixosHardware;
          srvos = srvos.nixosModules;
        };
      });

    darwinConfigurations = lib.genAttrs (hostsList darwinHostsPath) (hostname:
      printMachine hostname nix-darwin.lib.darwinSystem {
        modules =
          darwinModules.default
          ++ [clusterConfigModule]
          ++ (hostModules darwinHostsPath hostname)
          ++ extraModules;
        specialArgs = {
          hardware = importHardware darwinHardware;
        };
      });

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
          # TODO workaround: do not build x86_64 machines locally as it is assumed the local builder is aarch64-darwin
          remoteBuild = hostPlatform.isx86;
          profiles = {
            system = {
              inherit path;
              sshOpts = ["-o" "HostName=${config.settings.wireguard.ip}"] ++ optionalSshOpts;
            };
            lan = {
              inherit path;
              sshOpts = ["-o" "HostName=${config.settings.localIP}"] ++ optionalSshOpts;
            };
            public = {
              inherit path;
              sshOpts = ["-o" "HostName=${config.settings.publicIP}"] ++ optionalSshOpts;
            };
          };
        })
      hostsConfig;
    };

    # Contains the configuration of all the machines in the cluster
    hostsConfig = lib.mapAttrs (_: sys: sys.config) (nixosConfigurations // darwinConfigurations);

    /*
    Accessible by:
    (1) the host that uses the related wireguard secret
    (2) cluster admins
    */
    wireGuardSecrets =
      lib.mapAttrs'
      (
        name: cfg: let
          path =
            if cfg.nixpkgs.hostPlatform.isDarwin
            then cfg.cluster.hosts.darwinPath
            else cfg.cluster.hosts.nixosPath;
        in
          lib.nameValuePair
          "${path}/${name}.wg.age"
          {
            publicKeys =
              [cfg.settings.sshPublicKey] # (1)
              ++ clusterAdminKeys; # (2)
          }
      )
      hostsConfig;

    /*
    Accessible by:
    (1) users with config.users.users.<user>.openssh.authorizedKeys.keys in at least one of the hosts
    (2) hosts where the user exists (config.users.users exists)
    (3) cluster admins
    */
    usersSecrets =
      if (usersPath == null)
      then {}
      else
        lib.foldlAttrs (
          hostAcc: _: host:
            lib.foldlAttrs (
              userAcc: userName: user: let
                userKeys = lib.attrByPath ["openssh" "authorizedKeys" "keys"] [] user;
                keyName = "${usersPath}/${userName}.hash.age";
                currentKeys = lib.attrByPath [keyName "publicKeys"] [] userAcc;
              in
                userAcc
                // {
                  "${keyName}".publicKeys = lib.unique (
                    builtins.map trimPublicKey
                    (
                      currentKeys
                      ++ clusterAdminKeys # (3)
                      ++ [host.settings.sshPublicKey] # (2)
                      ++ (lib.optionals ((builtins.length userKeys) > 0) userKeys) # (1)
                    )
                  );
                }
            )
            hostAcc
            host.users.users
        )
        {}
        hostsConfig;

    /*
    Accessible by:
    (1) hosts with wifi enabled (1)
    (2) cluster admins
    */
    wifiSecret =
      if (wifiPath != null)
      then {
        "${wifiPath}/psk.age".publicKeys =
          lib.foldlAttrs (
            acc: _: cfg:
              acc # (1)
              ++ (lib.optional (
                  builtins.hasAttr "wireless" cfg.networking # cfg.networking.wireless is not defined on darwin
                  && cfg.networking.wireless.enable
                )
                cfg.settings.sshPublicKey)
          )
          # (2)
          clusterAdminKeys
          hostsConfig;
      }
      else {};

    # Cluster object, that contains the cluster configuration
    cluster = {
      # ? projectRoot
      hosts = {
        config = hostsConfig;
        nixosPath = nixosHostsPath;
        darwinPath = darwinHostsPath;
      };
      users = {
        path = usersPath;
      };
      secrets = {
        config = wireGuardSecrets // usersSecrets // wifiSecret;
        adminKeys = clusterAdminKeys;
      };
      wifi = {
        path = wifiPath;
      };
      hardware = {
        nixos = nixosHardware;
        darwin = darwinHardware;
      };
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
