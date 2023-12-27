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
    builderPath ? null,
    ...
  }: {config, ...}: let
    builderFeature = builderPath != null;
    isBuilder = config.settings.services.nix-builder.enable;
  in {
    settings.services.nix-builder.ssh = lib.mkIf builderFeature {
      privateKeyFile = config.age.secrets.nix-builder.path;
      publicKey = lib.mkIf isBuilder (builtins.readFile (projectRoot + "/${builderPath}/key.pub"));
    };

    # Load user passwords
    age.secrets =
      {}
      // lib.optionalAttrs builderFeature {
        # Load the Nix Builder private key on evey machine
        nix-builder = {
          file = projectRoot + "/${builderPath}/key.age";
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
    builderPath ? null,
    clusterAdminKeys,
    hostsConfig,
    ...
  }:
    if (builderPath != null)
    then {
      "${builderPath}/key.age".publicKeys =
        (lib.mapAttrsToList (_: cfg: cfg.settings.sshPublicKey) hostsConfig) # (1)
        ++ clusterAdminKeys; # (2)
    }
    else {};
in {
  inherit
    buildersModule
    nixBuilderSecret
    ;
}
