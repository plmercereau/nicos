{lib}: let
  # compose [ f g h ] x == f (g (h x))
  compose = let
    apply = f: x: f x;
  in
    lib.flip (lib.foldr apply);

  filterEnabled = lib.filterAttrs (_: conf: conf.enable);

  # Recursively merge a list of attrsets
  recursiveMerge = lib.foldl lib.recursiveUpdate {};

  listHosts = hostsPath: os: let
    jsonFiles = lib.filterAttrs (name: type: type == "regular" && (lib.hasSuffix ".json" name) && lib.hasSuffix os (lib.importJSON "${builtins.toPath hostsPath}/${name}").platform) (builtins.readDir hostsPath);
  in
    builtins.map (fileName: lib.removeSuffix ".json" fileName) (lib.attrNames jsonFiles);

  mkExtraModules = hostname: mainPath: let
    jsonHostsConfig = loadHostsJSON "${mainPath}/hosts";
    jsonConfig = jsonHostsConfig.${hostname};
    usersConfig = loadUsersConfig (mainPath + "/users");
  in [
    (mainPath + "/hosts/${hostname}.nix")
    ({config, ...}: let
      gui = config.settings.gui.enable;
    in {
      nixpkgs.hostPlatform = jsonConfig.platform;
      # Set the hostname from the file name
      networking.hostName = hostname;
      # Load SSH and wireguard configuration
      settings = {
        hosts = lib.mapAttrs (name: cfg:
          lib.getAttrs ["id" "publicKey" "wgPublicKey" "bastion" "ip"] ({
              bastion = false;
            }
            // cfg))
        jsonHostsConfig;

        users.users = lib.mapAttrs (name: cfg:
          cfg
          // {
            passwordSecretFile = mainPath + "/users/${name}.hash.age";
            # TODO not ideal - let's see when we'll have more than one user
            home-manager =
              mainPath
              + "/home-manager/profile-${
                if gui
                then "gui"
                else "cli"
              }.nix";
          })
        usersConfig;
      };
    })
  ];

  evalNixosHost = mainPath: defaultModules: flakeInputs: {
    nixpkgs,
    hostname,
    extraModules ? [],
    extraSpecialArgs ? {},
  }: let
    jsonHostsConfig = loadHostsJSON "${mainPath}/hosts";
    jsonConfig = jsonHostsConfig.${hostname};
    printHostname = lib.trace "Evaluating config: ${hostname}";
  in
    printHostname (
      nixpkgs.lib.nixosSystem {
        # The nixpkgs instance passed down here has potentially been overriden by the host override
        specialArgs =
          {
            flakeInputs = flakeInputs // {inherit nixpkgs;};
            inherit mainPath;
          }
          // extraSpecialArgs;
        modules = defaultModules ++ extraModules;
      }
    );

  # Construct the set of nixos configs, adding the given additional host overrides
  mkNixosConfigurations = {
    mainPath,
    nixpkgs,
    defaultModules,
    flakeInputs,
  }:
    builtins.listToAttrs (builtins.map (hostname: {
      name = hostname;
      value = evalNixosHost mainPath defaultModules flakeInputs {
        inherit nixpkgs hostname;
        extraModules = mkExtraModules hostname mainPath;
      };
    }) (listHosts "${mainPath}/hosts" "linux"));

  evalDarwinHost = mainPath: defaultModules: flakeInputs: {
    nix-darwin,
    hostname,
    extraModules ? [],
    extraSpecialArgs ? {},
  }: let
    printHostname = lib.trace "Evaluating config: ${hostname}";
  in
    printHostname (
      nix-darwin.lib.darwinSystem {
        specialArgs = {inherit flakeInputs;} // extraSpecialArgs;
        modules = defaultModules ++ extraModules;
      }
    );

  mkDarwinConfigurations = {
    mainPath,
    nix-darwin,
    defaultModules,
    flakeInputs,
  }:
    builtins.listToAttrs (builtins.map (hostname: {
      name = hostname;
      value = evalDarwinHost mainPath defaultModules flakeInputs {
        inherit nix-darwin hostname;
        extraModules = mkExtraModules hostname mainPath;
      };
    }) (listHosts "${mainPath}/hosts" "darwin"));

  #Poached from https://github.com/thexyno/nixos-config/blob/28223850747c4298935372f6691456be96706fe0/lib/attrs.nix#L10
  # mapFilterAttrs ::
  #   (name -> value -> bool)
  #   (name -> value -> { name = any; value = any; })
  #   attrs
  mapFilterAttrs = pred: f: attrs: lib.filterAttrs pred (lib.mapAttrs' f attrs);

  # Poached from https://github.com/thexyno/nixos-config/blob/28223850747c4298935372f6691456be96706fe0/lib/modules.nix#L9
  mapModules = dir: fn:
    mapFilterAttrs
    (n: v:
      v
      != null
      && !(lib.hasPrefix "_" n))
    (n: v: let
      path = "${toString dir}/${n}";
    in
      if v == "directory" && lib.pathExists "${path}/default.nix"
      then lib.nameValuePair n (fn path)
      else if
        v
        == "regular"
        && n != "default.nix"
        && lib.hasSuffix ".nix" n
      then lib.nameValuePair (lib.removeSuffix ".nix" n) (fn path)
      else lib.nameValuePair "" null)
    (builtins.readDir dir);

  loadHostJSON = hostsPath: name: lib.importJSON "${builtins.toPath hostsPath}/${name}.json";

  loadHostsJSON = hostsPath: let
    hostConfigs =
      lib.mapAttrs'
      (fileName: value: let
        name = lib.removeSuffix ".json" fileName;
      in
        lib.nameValuePair name
        (loadHostJSON hostsPath name))
      (lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".json" name)
        (builtins.readDir (builtins.toPath hostsPath)));
  in
    assert (
      # CHECK: All hosts have a unique id
      let
        ids = lib.mapAttrsToList (name: cfg: cfg.id) hostConfigs;
      in
        (lib.unique ids) == ids
    ); hostConfigs;

  loadUsersConfig = usersPath: let
    files = builtins.readDir usersPath;
    tomlFiles = lib.filterAttrs (name: _: lib.hasSuffix ".toml" name) files;
  in
    lib.mapAttrs' (
      fileName: _: (lib.nameValuePair
        (lib.removeSuffix ".toml" fileName)
        (builtins.fromTOML (builtins.readFile "${builtins.toPath usersPath}/${fileName}")))
    )
    tomlFiles;

  # Admins are all users defined in users/*.toml with admin = true
  mkAdminsKeys = usersPath: let
    users = loadUsersConfig usersPath;
  in
    lib.filterAttrs (name: value: (builtins.hasAttr "admin" value) && value.admin == true) users;

  mkAdminsKeysList = usersPath: let
    admins = mkAdminsKeys usersPath;
  in
    builtins.concatLists (builtins.attrValues (builtins.mapAttrs (name: value: value.public_keys) admins));

  mkHostsKeysList = hostsPath: let
    loadHostsKeys = hostsPath: lib.mapAttrsToList (name: value: value.publicKey) (loadHostsJSON hostsPath);
  in
    loadHostsKeys hostsPath;

  # Admins are all users defined in users/*.nix with admin = true
  # admins = lib.filterAttrs (name: value: builtins.hasAttr "admin" value && value.admin == true) users;
  # adminsKeys = concatLists (attrValues (builtins.mapAttrs (name: value: value.public_keys) admins));

  mkWireGuardSecrets = mainPath: inputs: let
    hostsConfig = loadHostsJSON (mainPath + "/hosts");
    adminsKeys = mkAdminsKeysList (mainPath + "/users");
    hostsKeys = mkHostsKeysList (mainPath + "/hosts");
  in
    lib.mapAttrs'
    (name: value: lib.nameValuePair "./hosts/${name}.wg.age" {publicKeys = adminsKeys ++ hostsKeys;})
    hostsConfig;

  # * add per-user *.hash.age
  mkUsersSecrets = mainPath: inputs: let
    usersConfig = loadUsersConfig (mainPath + "/users");
    adminsKeys = mkAdminsKeysList (mainPath + "/users");
    hostsKeys = mkHostsKeysList (mainPath + "/hosts");
  in
    lib.mapAttrs'
    (name: value: lib.nameValuePair "./users/${name}.hash.age" {publicKeys = value.public_keys ++ adminsKeys ++ hostsKeys;})
    usersConfig;
in {
  inherit
    compose
    filterEnabled
    recursiveMerge
    mkDarwinConfigurations
    mkNixosConfigurations
    loadHostsJSON
    mkAdminsKeysList
    mkUsersSecrets
    mkHostsKeysList
    mkWireGuardSecrets
    ;
}
