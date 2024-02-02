{pkgs}: let
  inherit (pkgs) lib;
in
  # ? use helm template to avoid a dependency on a remote chart (put the chart in the repo -> nix store)
  # ? don't allow "latest" helm charts ?
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
