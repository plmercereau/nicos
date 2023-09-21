{lib}: let
  # compose [ f g h ] x == f (g (h x))
  compose = let
    apply = f: x: f x;
  in
    lib.flip (lib.foldr apply);

  filterEnabled = lib.filterAttrs (_: conf: conf.enable);

  toHostPath = hostsPath: hostname: hostsPath + "/${hostname}.nix";

  # Recursively merge a list of attrsets
  recursiveMerge = lib.foldl lib.recursiveUpdate {};

  listHosts = hostsPath: os: let
    jsonFiles = lib.filterAttrs (name: type: type == "regular" && (lib.hasSuffix ".json" name) && lib.hasSuffix os (lib.importJSON "${builtins.toPath hostsPath}/${name}").platform) (builtins.readDir hostsPath);
  in
    builtins.map (fileName: lib.removeSuffix ".json" fileName) (lib.attrNames jsonFiles);

  # Load all the users from the users directory
  mkUsersSettings = with lib;
    usersPath: inputs: let
      users =
        mapModules usersPath (file: (import file inputs));
    in {
      settings.users.users = mapAttrs (name: conf: let
        secretPath = usersPath + "/${name}.hash.age";
      in
        conf // {passwordSecretFile = mkIf (pathExists secretPath) secretPath;})
      users;
    };

  evalNixosHost = orgConfigPath: defaultModules: flakeInputs: {
    nixpkgs,
    hostname,
    extraModules ? [],
    extraSpecialArgs ? {},
  }: let
    hostsPath = "${orgConfigPath}/hosts";
    usersPath = "${orgConfigPath}/users";
    jsonHostsConfig = loadHostsJSON hostsPath;
    jsonConfig = jsonHostsConfig.${hostname};
    printHostname = lib.trace "Evaluating config: ${hostname}";
  in
    printHostname (
      nixpkgs.lib.nixosSystem {
        # The nixpkgs instance passed down here has potentially been overriden by the host override
        specialArgs =
          {
            flakeInputs = flakeInputs // {inherit nixpkgs;};
            inherit orgConfigPath;
          }
          // extraSpecialArgs;
        modules =
          [
            {nixpkgs.hostPlatform = jsonConfig.platform;}
            (toHostPath hostsPath hostname)
            ./modules/linux/wifi.nix
            # Set the hostname from the file name
            {networking.hostName = hostname;}
            # Load all the users from the users directory
            (inputs: mkUsersSettings usersPath inputs)
            # Load SSH and tunnel configuration
            {
              settings = {
                tunnel = lib.mkIf (lib.hasAttr "tunnelId" jsonConfig) {
                  enable = true;
                  port = jsonConfig.tunnelId;
                };
                hosts = lib.mapAttrs (name: cfg: lib.getAttrs ["tunnelId" "ip" "publicKey"] ({tunnelId = null;} // cfg)) jsonHostsConfig;
              };
            }
          ]
          ++ defaultModules
          ++ extraModules;
      }
    );

  # Construct the set of nixos configs, adding the given additional host overrides
  mkNixosConfigurations = {
    orgConfigPath,
    nixpkgs,
    defaultModules,
    flakeInputs,
    hostOverrides,
  }: let
    # Generate an attrset containing one attribute per host
    evalHosts =
      lib.mapAttrs (hostname: args:
        evalNixosHost orgConfigPath defaultModules flakeInputs args);

    hosts = builtins.listToAttrs (builtins.map (name: {
      inherit name;
      value = {
        inherit nixpkgs;
        hostname = name;
      };
    }) (listHosts "${orgConfigPath}/hosts" "linux"));
  in
    # Merge in the set of overrided and pass to evalHosts
    evalHosts (lib.recursiveUpdate hosts hostOverrides);

  # TODO at a later stage, we should put all the nixos+darwin hosts into a single flat directory
  # ? in each file, determine the system (darwin or nixos + arch) from what's inside the file -> complicated as it would require to eval the files
  # ? Or add another file like hosts.json that contains the system for each host (not ideal)
  evalDarwinHost = orgConfigPath: defaultModules: flakeInputs: {
    nix-darwin,
    hostname,
    extraModules ? [],
    extraSpecialArgs ? {},
  }: let
    hostsPath = "${orgConfigPath}/hosts";
    usersPath = "${orgConfigPath}/users";
    jsonHostsConfig = loadHostsJSON hostsPath;
    jsonConfig = jsonHostsConfig.${hostname};
    printHostname = lib.trace "Evaluating config: ${hostname}";
  in
    printHostname (
      nix-darwin.lib.darwinSystem {
        # TODO different in nixos: The nixpkgs instance passed down here has potentially been overriden by the host override
        specialArgs = {inherit flakeInputs;} // extraSpecialArgs;
        modules =
          [
            {nixpkgs.hostPlatform = jsonConfig.platform;}
            (toHostPath hostsPath hostname)
            # Set the hostname from the file name
            {networking.hostName = hostname;}
            # Load all the users from the users directory
            (inputs: mkUsersSettings usersPath inputs)
            # Load SSH and tunnel configuration
            {
              settings = {
                tunnel = lib.mkIf (lib.hasAttr "tunnelId" jsonConfig) {
                  enable = true;
                  port = jsonConfig.tunnelId;
                };
                hosts = lib.mapAttrs (name: cfg: lib.getAttrs ["tunnelId" "ip" "publicKey"] ({tunnelId = null;} // cfg)) jsonHostsConfig;
              };
            }
          ]
          ++ defaultModules
          ++ extraModules;
      }
    );

  mkDarwinConfigurations = {
    orgConfigPath,
    nix-darwin,
    defaultModules,
    flakeInputs,
    hostOverrides,
  }: let
    # Generate an attrset containing one attribute per host
    evalHosts =
      lib.mapAttrs (hostname: args:
        evalDarwinHost orgConfigPath defaultModules flakeInputs args);

    hosts = builtins.listToAttrs (builtins.map (name: {
      inherit name;
      value = {
        inherit nix-darwin;
        hostname = name;
      };
    }) (listHosts "${orgConfigPath}/hosts" "darwin"));
  in
    # Merge in the set of overrided and pass to evalHosts
    evalHosts (lib.recursiveUpdate hosts hostOverrides);

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

  loadHostsJSON = hostsPath:
    lib.mapAttrs'
    (fileName: value: let
      name = lib.removeSuffix ".json" fileName;
    in
      lib.nameValuePair name
      (loadHostJSON hostsPath name))
    (lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".json" name)
      (builtins.readDir (builtins.toPath hostsPath)));

  mkUsersList = usersPath: inputs: let
    userSettings = mkUsersSettings usersPath inputs;
  in
    userSettings.settings.users.users;

  # Admins are all users defined in ../users/*.nix with admin = true
  mkAdminsKeys = usersPath: inputs: let
    users = mkUsersList inputs usersPath;
  in
    lib.filterAttrs (name: value: builtins.hasAttr "admin" value && value.admin == true) users;

  mkAdminsKeysList = usersPath: inputs: let
    admins = mkAdminsKeys inputs usersPath;
  in
    builtins.concatLists (builtins.attrValues (builtins.mapAttrs (name: value: value.public_keys) admins));

  mkHostsKeysList = hostsPath: let
    loadHostsKeys = hostsPath: lib.mapAttrsToList (name: value: value.publicKey) (loadHostsJSON hostsPath);
  in
    loadHostsKeys hostsPath;

  # Admins are all users defined in ../users/*.nix with admin = true
  # admins = lib.filterAttrs (name: value: builtins.hasAttr "admin" value && value.admin == true) users;
  # adminsKeys = concatLists (attrValues (builtins.mapAttrs (name: value: value.public_keys) admins));

  # * add per-user *.hash.age
  mkUsersSecrets = orgConfigPath: inputs: let
    usersPath = orgConfigPath + "/users";
    hostsPath = orgConfigPath + "/hosts";
    userSettings = mkUsersSettings usersPath inputs;
    users = userSettings.settings.users.users;
    adminsKeys = mkAdminsKeysList usersPath inputs;
    hostsKeys = mkHostsKeysList hostsPath;
  in
    lib.mapAttrs'
    (name: value: lib.nameValuePair "./users/${name}.hash.age" {publicKeys = value.public_keys ++ adminsKeys ++ hostsKeys;})
    users;
in {
  inherit
    compose
    filterEnabled
    recursiveMerge
    mkDarwinConfigurations
    mkNixosConfigurations
    mkUsersSettings
    loadHostsJSON
    mkAdminsKeysList
    mkUsersSecrets
    mkHostsKeysList
    ;
}
