let
  lib = import ./lib.nix {};
in
  lib.mkSecretsKeys {}
