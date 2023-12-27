let
  pkgs = import <nixpkgs> {};
  inherit (pkgs) lib;

  pick = filters: input:
    lib.foldl (acc: curr: let
      path = lib.splitString "." curr;
      value = pickOne path input;
    in
      lib.recursiveUpdate acc value) {}
    filters;

  pickOne = path: input: let
    star = lib.lists.findFirstIndex (x: x == "*") null path;
  in
    if star == null
    then let
      value = lib.attrByPath path null input;
    in
      lib.setAttrByPath path value
    else let
      # ! not tested if path starts or ends with *
      pathBefore = lib.lists.take star path;
      pathAfter = lib.lists.drop (star + 1) path;
      valueAfter = lib.attrByPath pathBefore null input;
      filteredValueAfter = lib.mapAttrs (name: value: pickOne pathAfter value) valueAfter;
    in
      lib.setAttrByPath pathBefore filteredValueAfter;

  getFlake = path: let
    flake = builtins.getFlake path;
    darwin = lib.attrByPath ["darwinConfigurations"] {} flake;
    nixos = lib.attrByPath ["nixosConfigurations"] {} flake;
  in
    flake
    // {
      # We do not use cluster.hosts here so we don't need to instanciate `cluster` in the flake using the `configure` wrapper.
      # In doing so, the CLI can work without configuring the cluster and should work with any flake.
      configs = nixos // darwin;
    };

  pickInFlake = path: filters: pick filters (getFlake path);
in {inherit pick getFlake pickInFlake;}
