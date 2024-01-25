{
  lib,
  pkgs,
  stdenv,
  ...
}: name: tree: let
  flatten = prefix: set: let
    recurse = name: value:
      if lib.isAttrs value
      then flatten (prefix + name + "/") value
      else {${prefix + name} = value;};
  in
    lib.foldl' (acc: name: acc // recurse name set.${name})
    {}
    (lib.attrNames set);
in
  stdenv.mkDerivation rec {
    inherit name;
    buildInputs = [];
    phases = ["buildPhase"];
    buildPhase = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: value: ''
        mkdir -p $out/$(dirname ${name})
        cp ${(pkgs.writeText "file" value).outPath} $out/${name}
      '')
      (flatten "" tree));
  }
