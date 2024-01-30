{nixpkgs, ...}: let
  module = {
    config,
    cluster,
    lib,
    ...
  }:
    with lib; let
      inherit (cluster) projectRoot nixos darwin;
      vpn = config.settings.networking.vpn;
      hostsPath =
        if config.nixpkgs.hostPlatform.isDarwin
        then darwin.path
        else nixos.path;
    in
      mkIf vpn.enable {
        # Load Wireguard private key
        age.secrets.vpn.file = projectRoot + "/${hostsPath}/${config.networking.hostName}.vpn.age";
        # Path to the private key file.
        networking.wg-quick.interfaces.${vpn.interface}.privateKeyFile = config.age.secrets.vpn.path;
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
    with nixpkgs.lib;
      lib.mapAttrs'
      (
        name: cfg: let
          path =
            if cfg.nixpkgs.hostPlatform.isDarwin
            then darwin.path
            else nixos.path;
        in
          nameValuePair
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
