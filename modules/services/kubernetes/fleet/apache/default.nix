{pkgs}: let
  inherit (pkgs) lib;
in
  pkgs.stdenv.mkDerivation {
    name = "apache-test-chart";

    src =
      builtins.filterSource
      (path: type: lib.strings.hasSuffix ".yaml" path)
      ./.;

    buildPhase = ''
      # Your build commands here
    '';

    installPhase = ''
      mkdir -p $out
      cp -r . $out/apache
    '';

    meta = {
      description = "A custom derivation from a folder";
      # Other metadata fields
    };
  }
