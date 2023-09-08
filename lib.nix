{lib}: let
  # compose [ f g h ] x == f (g (h x))
  compose = let
    apply = f: x: f x;
  in
    lib.flip (lib.foldr apply);

  applyN = n: f: compose (lib.genList (lib.const f) n);

  applyTwice = applyN 2;

  filterEnabled = lib.filterAttrs (_: conf: conf.enable);

  # concatMapAttrsToList :: (String -> v -> [a]) -> AttrSet -> [a]
  concatMapAttrsToList = f:
    compose [
      lib.concatLists
      (lib.mapAttrsToList f)
    ];

  toHostPath = hostsPath: hostname: hostsPath + "/${hostname}.nix";

  # Recursively merge a list of attrsets
  recursiveMerge = lib.foldl lib.recursiveUpdate {};

  stringNotEmpty = s: lib.stringLength s != 0;

  # Load all the users from the users directory
  mkUsersSettings = with lib;
    usersPath: inputs: let
      users =
        mapModules usersPath (file:
          import file inputs);
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
    hostsPath = "${orgConfigPath}/hosts/linux";
    usersPath = "${orgConfigPath}/users";
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
            (toHostPath hostsPath hostname)
            # Set the hostname from the file name
            {networking.hostName = hostname;}
            # Load all the users from the users directory
            (inputs: mkUsersSettings usersPath inputs)
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
    hostsPath = "${orgConfigPath}/hosts/linux";
    # Generate an attrset containing one attribute per host
    evalHosts = lib.mapAttrs (hostname: args:
      evalNixosHost orgConfigPath defaultModules flakeInputs (args
        // {
          inherit hostname;
        }));

    hosts =
      lib.mapAttrs'
      (fileName: _:
        lib.nameValuePair (lib.removeSuffix ".nix" fileName) {
          inherit nixpkgs;
        })
      (lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".nix" name)
        (builtins.readDir hostsPath));
  in
    # Merge in the set of overrided and pass to evalHosts
    evalHosts (lib.recursiveUpdate hosts hostOverrides);

  # TODO at a later stage, we should put all the nixos+darwin hosts into a single flat directory
  # ? in each file, determine the system (darwin or nixos + arch) from what's inside the file
  # ? Or add another file like hosts.json that contains the system for each host (not ideal)
  evalDarwinHost = orgConfigPath: defaultModules: flakeInputs: {
    nix-darwin,
    hostname,
    extraModules ? [],
    extraSpecialArgs ? {},
  }: let
    hostsPath = "${orgConfigPath}/hosts/darwin";
    usersPath = "${orgConfigPath}/users";
    printHostname = lib.trace "Evaluating config: ${hostname}";
  in
    printHostname (
      nix-darwin.lib.darwinSystem {
        # TODO different in nixos: The nixpkgs instance passed down here has potentially been overriden by the host override
        specialArgs = {inherit flakeInputs;} // extraSpecialArgs;
        modules =
          [
            (toHostPath hostsPath hostname)
            # Set the hostname from the file name
            {networking.hostName = hostname;}
            # Load all the users from the users directory
            (inputs: mkUsersSettings usersPath inputs)
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
    hostsPath = "${orgConfigPath}/hosts/darwin";
    # Generate an attrset containing one attribute per host
    evalHosts = lib.mapAttrs (hostname: args:
      evalDarwinHost orgConfigPath defaultModules flakeInputs (args
        // {
          inherit hostname;
        }));

    hosts =
      lib.mapAttrs'
      (fileName: _:
        lib.nameValuePair (lib.removeSuffix ".nix" fileName) {
          inherit nix-darwin;
        })
      (lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".nix" name)
        (builtins.readDir hostsPath));
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

  # Slice a list up in equally-sized slices and return the requested one
  getSlice = {
    slice,
    sliceCount,
    list,
  }: let
    len = lib.length list;

    # Let's imagine a list of 10 elements, and 4 slices, in that case the slice_size is 10 / 4 = 2
    # and the modulo is 10 % 4 = 2. We thus need to add an additional element to the first
    # two slices, and not to the two following ones. The below formulas do exactly that:
    # 1: from 0 * 2 + min(0, 2) = 0, size 2 + 1 = 3 (because 0 <  2), so [0:3]  = [0, 1, 2]
    # 2: from 1 * 2 + min(1, 2) = 3, size 2 + 1 = 3 (because 1 <  2), so [3:6]  = [3, 4, 5]
    # 3: from 2 * 2 + min(2, 2) = 6, size 2 + 0 = 2 (because 2 >= 2), so [6:8]  = [6, 7]
    # 4: from 3 * 2 + min(3, 2) = 8, size 2 + 0 = 2 (because 3 >= 2), so [8:10] = [8, 9]
    sliceSize = len / sliceCount;
    modulo = len - (sliceSize * sliceCount);
    begin = slice * sliceSize + (lib.min slice modulo);
    size =
      sliceSize
      + (
        if (slice < modulo)
        then 1
        else 0
      );
  in
    lib.sublist begin size list;
in {
  inherit
    compose
    applyTwice
    filterEnabled
    concatMapAttrsToList
    stringNotEmpty
    recursiveMerge
    mkDarwinConfigurations
    mkNixosConfigurations
    mkUsersSettings
    getSlice
    ;
}
