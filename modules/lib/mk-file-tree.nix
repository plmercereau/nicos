# TODO unused
{
  lib,
  pkgs,
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
  /*
  Transforms an attrs tree with string values into a corresponding tree of text files.
  For instance, the following tree:

  {
    "foo.txt" = "contents of foo";
    baz = {
      bar = "quux";
    };
  }

  will create a derivation with the following files:
  foo.txt # contents of foo
  baz/bar # quux
  */
  pkgs.stdenv.mkDerivation {
    inherit name;
    buildInputs = [];
    phases = ["buildPhase"];
    buildPhase = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: value: ''
        mkdir -p $out/$(dirname ${name})
        cp ${(pkgs.writeText "file" value).outPath} $out/${name}
      '')
      (flatten "" tree));
  }
