{lib ? (import <nixpkgs> {}).lib}: let
  # compose [ f g h ] x == f (g (h x))
  compose = let
    apply = f: x: f x;
  in
    lib.flip (lib.foldr apply);

  filterEnabled = lib.filterAttrs (_: conf: conf.enable);

  mkExtraModules = {
    hostname,
    projectRoot,
    hostsPath,
    usersPath,
  }: let
    hostsConfig = loadHostsConfig projectRoot hostsPath;
    usersConfig = loadUsersConfig projectRoot usersPath;
  in [
    (projectRoot + "/${hostsPath}/${hostname}.nix")
    ({config, ...}: {
      nixpkgs.hostPlatform = hostsConfig.${hostname}.platform;
      # Set the hostname from the file name
      networking.hostName = hostname;
      age.secrets = lib.mkMerge [
        # Load SSH and wireguard configuration
        {wireguard.file = projectRoot + "/${hostsPath}/${hostname}.wg.age";}
        # Load user passwords
        (
          lib.mapAttrs' (
            name: cfg: lib.nameValuePair "password_${name}" {file = projectRoot + "/${usersPath}/${name}.hash.age";}
          )
          # * at this point, we don't know if the user is enabled or not, so we can't use loadUsersConfig
          (filterEnabled config.settings.users.users)
        )
      ];
      settings = {
        hosts = hostsConfig;
        users.users = usersConfig;
      };
    })
  ];

  printHostname = hostname: lib.trace "Evaluating config: ${hostname}";

  # Construct the set of nixos configs, adding the given additional host overrides
  mkNixosConfigurations = {
    nixpkgs,
    defaultModules,
    projectRoot,
    hostsPath ? "./hosts",
    usersPath ? "./users",
  }: let
    hosts = loadHostsConfig projectRoot hostsPath;
    linuxHosts = lib.filterAttrs (name: config: lib.hasSuffix "linux" config.platform) hosts;
  in
    builtins.mapAttrs (
      hostname: _:
        printHostname hostname (nixpkgs.lib.nixosSystem {
          modules = defaultModules ++ (mkExtraModules {inherit hostname projectRoot hostsPath usersPath;});
        })
    )
    linuxHosts;

  mkDarwinConfigurations = {
    nix-darwin,
    defaultModules,
    projectRoot,
    hostsPath ? "./hosts",
    usersPath ? "./users",
  }: let
    hosts = loadHostsConfig projectRoot hostsPath;
    linuxHosts = lib.filterAttrs (name: config: lib.hasSuffix "darwin" config.platform) hosts;
  in
    builtins.mapAttrs (
      hostname: _:
        printHostname hostname (nix-darwin.lib.darwinSystem {
          modules = defaultModules ++ (mkExtraModules {inherit hostname projectRoot hostsPath usersPath;});
        })
    )
    linuxHosts;

  loadHostsConfig = projectRoot: hostsPath: let
    path = projectRoot + "/${hostsPath}";
    hostConfigs =
      lib.mapAttrs'
      (fileName: value: let
        name = lib.removeSuffix ".toml" fileName;
      in
        lib.nameValuePair name
        ({
            localIP = null;
            publicIP = null;
            builder = false;
          }
          // lib.importTOML (path + "/${name}.toml")))
      (lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".toml" name)
        (builtins.readDir path));
  in
    assert (
      # CHECK: All hosts have a unique id
      let
        ids = lib.mapAttrsToList (name: cfg: cfg.id) hostConfigs;
      in
        (lib.unique ids) == ids
    ); hostConfigs;

  loadUsersConfig = projectRoot: usersPath: let
    path = projectRoot + "/${usersPath}";
    files = builtins.readDir path;
    tomlFiles = lib.filterAttrs (name: _: lib.hasSuffix ".toml" name) files;
  in
    lib.mapAttrs' (
      fileName: _: (lib.nameValuePair
        (lib.removeSuffix ".toml" fileName)
        (builtins.fromTOML (builtins.readFile (path + "/${fileName}"))))
    )
    tomlFiles;

  mkSecretsKeys = {
    projectRoot ? ./.,
    hostsPath ? "./hosts",
    usersPath ? "./users",
    wifiPath ? "./wifi/psk.age",
  }: let
    hostsConfig = loadHostsConfig projectRoot hostsPath;
    usersConfig = loadUsersConfig projectRoot usersPath;
    admins = lib.filterAttrs (name: value: (builtins.hasAttr "admin" value) && value.admin == true) usersConfig;
    adminsKeys = builtins.concatLists (builtins.attrValues (builtins.mapAttrs (name: value: value.public_keys) admins));
    hostsKeys = lib.mapAttrsToList (name: value: value.sshPublicKey) hostsConfig;

    wireGuardSecrets =
      lib.mapAttrs'
      (name: value: lib.nameValuePair "${hostsPath}/${name}.wg.age" {publicKeys = adminsKeys ++ hostsKeys;})
      hostsConfig;
    usersSecrets =
      lib.mapAttrs'
      (name: value: lib.nameValuePair "${usersPath}/${name}.hash.age" {publicKeys = value.public_keys ++ adminsKeys ++ hostsKeys;})
      usersConfig;
    wifiSecret = {
      "${wifiPath}".publicKeys = hostsKeys ++ adminsKeys;
    };
  in
    wifiSecret // wireGuardSecrets // usersSecrets;
in {
  inherit
    compose
    filterEnabled
    loadHostsConfig
    mkDarwinConfigurations
    mkNixosConfigurations
    mkSecretsKeys
    ;
}
