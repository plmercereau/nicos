{
  agenix,
  deploy-rs,
  disko,
  home-manager,
  impermanence,
  nixpkgs,
  ...
}:
with nixpkgs.lib; {
  module = {
    config,
    cluster,
    ...
  }: let
    inherit (cluster) projectRoot builders;
    isBuilder = config.settings.nix-builder.enable;
  in {
    settings.nix-builder.ssh = optionalAttrs builders.enable {
      privateKeyFile = config.age.secrets.nix-builder.path;
      publicKey = mkIf isBuilder (builtins.readFile (projectRoot + "/${builders.path}/key.pub"));
    };

    # Load user passwords
    age.secrets = optionalAttrs builders.enable {
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
  secrets = {
    builders,
    adminKeys,
    hosts,
    ...
  }:
    optionalAttrs builders.enable {
      "${builders.path}/key.age".publicKeys =
        (mapAttrsToList (_: cfg: cfg.settings.sshPublicKey) hosts) # (1)
        ++ adminKeys; # (2)
    };
}
