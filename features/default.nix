inputs @ {
  agenix,
  deploy-rs,
  disko,
  home-manager,
  impermanence,
  nixpkgs,
  srvos,
  ...
}:
with nixpkgs.lib; let
  features = [./builders.nix ./vpn.nix ./users.nix ./wifi.nix];
in {
  secrets = params:
    foldl (
      acc: curr: let
        nixFile = (import curr) inputs;
      in
        acc
        // (
          optionalAttrs (nixFile ? "secrets")
          (nixFile.secrets params)
        )
    ) {}
    features;

  modules =
    foldl (
      acc: curr: let
        nixFile = import curr inputs;
      in
        acc ++ (optional (nixFile ? "module") nixFile.module)
    ) []
    features;
}
