let
  pkgs = import <nixpkgs> {};
  inherit (pkgs) lib;

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
in
  filters: input:
    lib.foldl (acc: curr: let
      path = lib.splitString "." curr;
      value = pickOne path input;
    in
      lib.recursiveUpdate acc value) {}
    filters
