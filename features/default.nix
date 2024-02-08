inputs @ {
  agenix,
  deploy-rs,
  disko,
  home-manager,
  impermanence,
  nixpkgs,
  srvos,
  ...
}: let
  inherit (nixpkgs) lib;
  features = [./builders.nix ./vpn.nix ./users.nix ./wifi.nix];
in {
  secrets = params:
    lib.foldl (
      acc: curr: let
        nixFile = (import curr) inputs;
      in
        acc
        // (
          lib.optionalAttrs (nixFile ? "secrets")
          (nixFile.secrets params)
        )
    ) {}
    features;

  modules =
    lib.foldl (
      acc: curr: let
        nixFile = import curr inputs;
      in
        acc ++ (lib.optional (nixFile ? "module") nixFile.module)
    ) []
    features;
}
