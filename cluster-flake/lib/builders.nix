{
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

  buildersModule = {
    projectRoot,
    builders,
  }: {config, ...}: let
    isBuilder = config.settings.services.nix-builder.enable;
  in {
    settings.services.nix-builder.ssh = lib.mkIf builders.enable {
      privateKeyFile = config.age.secrets.nix-builder.path;
      publicKey = lib.mkIf isBuilder (builtins.readFile (projectRoot + "/${builders.path}/key.pub"));
    };

    # Load user passwords
    age.secrets = lib.optionalAttrs builders.enable {
      # Load the Nix Builder private key on evey machine
      nix-builder = {
        file = projectRoot + "/${builders.path}/key.age";
        mode = "400";
        owner = "root";
        group = "nixbld";
      };
    };
  };

  /*
  Nix Builder secret, accessible by
  (1) Any host
  (2) cluster admins
  */
  nixBuilderSecret = {
    builders,
    clusterAdminKeys,
    hostsConfig,
  }:
    lib.optionalAttrs builders.enable {
      "${builders.path}/key.age".publicKeys =
        (lib.mapAttrsToList (_: cfg: cfg.settings.sshPublicKey) hostsConfig) # (1)
        ++ clusterAdminKeys; # (2)
    };
in {
  inherit
    buildersModule
    nixBuilderSecret
    ;
}
