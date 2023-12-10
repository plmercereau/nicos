{
  nixpkgs,
  nix-darwin,
  deploy-rs,
  agenix,
  impermanence,
  home-manager,
  ...
}: let
  inherit (nixpkgs) lib;

  filterEnabled = lib.filterAttrs (_: conf: conf.enable);

  printMachine = name: lib.trace "Evaluating machine: ${name}";

  nixosModules.default = [
    agenix.nixosModules.default
    impermanence.nixosModules.impermanence
    home-manager.nixosModules.home-manager
    ./modules/linux
  ];

  darwinModules.default = [
    agenix.darwinModules.default
    home-manager.darwinModules.home-manager
    ./modules/darwin
  ];

  mkConfigurations = {
    projectRoot,
    clusterAdmins,
    nixosHostsPath ? null,
    darwinHostsPath ? null,
    usersPath,
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

    users = {
      path = usersPath;
      users =
        lib.foldlAttrs (acc: name: type:
          acc
          // lib.optionalAttrs (type == "regular" && lib.hasSuffix ".toml" name) {
            "${lib.removeSuffix ".toml" name}" = builtins.fromTOML (builtins.readFile (projectRoot + "/${usersPath}/${name}"));
          })
        {}
        (builtins.readDir (projectRoot + "/${usersPath}"));
    };

    clusterConfigModule = {config, ...}: {
      inherit cluster; # load the information about the cluster (hosts, users, secrets, wifi)
      settings = {
        users = {inherit (users) users;}; # load users ssh keys
      };
      # Load user passwords
      age.secrets = lib.mkMerge [
        (
          lib.mapAttrs' (
            name: cfg: lib.nameValuePair "password_${name}" {file = projectRoot + "/${users.path}/${name}.hash.age";}
          )
          # # filter out disabled users
          (filterEnabled config.settings.users.users)
        )
      ];
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
      });

    darwinConfigurations = lib.genAttrs (hostsList darwinHostsPath) (hostname:
      printMachine hostname nix-darwin.lib.darwinSystem {
        modules =
          darwinModules.default
          ++ [clusterConfigModule]
          ++ (hostModules darwinHostsPath hostname)
          ++ extraModules;
      });

    # Make all the NixOS and Darwin configurations deployable by deploy-rs
    deploy = {
      user = "root";
      nodes = builtins.mapAttrs (hostname: config: let
        inherit (config.nixpkgs) hostPlatform;
        printHostname = lib.trace "Evaluating deployment: ${hostname} (${hostPlatform.system})";
      in
        printHostname ({
            inherit hostname;
            # TODO workaround: do not build x86_64 machines locally as it is assumed the local builder is aarch64-darwin
            remoteBuild = hostPlatform.isx86;
            profiles.system.path =
              if (hostPlatform.isDarwin)
              then deploy-rs.lib.${hostPlatform.system}.activate.darwin darwinConfigurations."${hostname}"
              else deploy-rs.lib.${hostPlatform.system}.activate.nixos nixosConfigurations."${hostname}";
          }
          //
          # TODO workaround to be able to use sudo with darwin.
          # * See: https://github.com/serokell/deploy-rs/issues/78
          lib.optionalAttrs (hostPlatform.isDarwin) {
            magicRollback = true;
            sshOpts = ["-t"];
          }))
      hostsConfig;
    };

    hostsConfig = lib.mapAttrs (_: sys: sys.config) (nixosConfigurations // darwinConfigurations);

    cluster = {
      # ? projectRoot
      hosts = {
        config = hostsConfig;
        nixosPath = nixosHostsPath;
        darwinPath = darwinHostsPath;
      };
      users = {
        config = users;
        path = usersPath;
        admins = clusterAdmins;
      };
      secrets = {
        config = mkSecretsKeys {inherit hostsConfig users clusterAdmins wifiPath;};
      };
      wifi = {
        path = wifiPath;
      };
    };
  in {
    inherit nixosConfigurations darwinConfigurations deploy cluster;
  };

  mkSecretsKeys = {
    hostsConfig,
    users,
    wifiPath,
    clusterAdmins,
  }: let
    clusterAdminKeys = lib.foldlAttrs (acc: _: user: acc ++ user.public_keys) [] (lib.getAttrs clusterAdmins users.users);

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
    (1) hosts where the user is enabled
    (2) users owning the secret
    (3) cluster admins
    */
    usersSecrets =
      lib.mapAttrs'
      (userName: userConfig:
        lib.nameValuePair
        "${users.path}/${userName}.hash.age"
        {
          publicKeys = (
            lib.foldlAttrs
            (
              acc: hostName: hostConfig:
                acc
                ++ ( # (1)
                  lib.optional
                  ((builtins.hasAttr userName hostConfig.settings.users.users) && hostConfig.settings.users.users."${userName}".enable)
                  hostConfig.settings.sshPublicKey
                )
            )
            (
              userConfig.public_keys # (2)
              ++ clusterAdminKeys # (3)
            )
            hostsConfig
          );
        })
      users.users;

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
  in
    wireGuardSecrets // usersSecrets // wifiSecret;
in {
  inherit
    mkSecretsKeys
    mkConfigurations
    nixosModules
    darwinModules
    ;
}
