inputs @ {
  agenix,
  deploy-rs,
  disko,
  home-manager,
  impermanence,
  nix-darwin,
  nixpkgs,
  srvos,
  ...
}: let
  inherit (nixpkgs) lib;
  common = [./builders.nix ./vpn.nix ./users.nix];
  nixos = [./wifi.nix];
  darwin = [];
  all = common ++ nixos ++ darwin;
in {
  inherit common all;
  nixos = common ++ nixos;
  darwin = common ++ darwin;

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
    all;

  modules = selection:
    lib.foldl (
      acc: curr: let
        nixFile = import curr inputs;
      in
        acc ++ (lib.optional (nixFile ? "module") nixFile.module)
    ) []
    selection;
}
