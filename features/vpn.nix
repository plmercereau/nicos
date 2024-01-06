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

  module = {
    config,
    cluster,
    ...
  }: let
    inherit (cluster) projectRoot nixos darwin;
    vpn = config.settings.networking.vpn;
    hostsPath =
      if config.nixpkgs.hostPlatform.isDarwin
      then darwin.path
      else nixos.path;
  in {
    # Load Wireguard private key
    age.secrets = lib.optionalAttrs (vpn.enable) {
      vpn.file = projectRoot + "/${hostsPath}/${config.networking.hostName}.vpn.age";
    };
  };

  /*
  Accessible by:
  (1) the host that uses the related Wireguard secret
  (2) cluster admins
  */
  secrets = {
    adminKeys,
    hosts,
    nixos,
    darwin,
    ...
  }:
    lib.mapAttrs'
    (
      name: cfg: let
        path =
          if cfg.nixpkgs.hostPlatform.isDarwin
          then darwin.path
          else nixos.path;
      in
        lib.nameValuePair
        "${path}/${name}.vpn.age"
        {
          publicKeys =
            [cfg.settings.sshPublicKey] # (1)
            ++ adminKeys; # (2)
        }
    )
    hosts;
in {
  inherit
    module
    secrets
    ;
}
