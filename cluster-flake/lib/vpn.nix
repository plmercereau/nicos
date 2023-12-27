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

  vpnModule = {
    projectRoot,
    hostsPath ? null,
    ...
  }: hostsPath: ({config, ...}: let
  in {
    # Load Wireguard private key
    age.secrets.vpn.file = projectRoot + "/${hostsPath}/${config.networking.hostName}.vpn.age";
  });

  /*
  Accessible by:
  (1) the host that uses the related Wireguard secret
  (2) cluster admins
  */
  vpnSecrets = {
    clusterAdminKeys,
    hostsConfig,
    nixosHostsPath,
    darwinHostsPath,
    ...
  }:
    lib.mapAttrs'
    (
      name: cfg: let
        path =
          if cfg.nixpkgs.hostPlatform.isDarwin
          then darwinHostsPath
          else nixosHostsPath;
      in
        lib.nameValuePair
        "${path}/${name}.vpn.age"
        {
          publicKeys =
            [cfg.settings.sshPublicKey] # (1)
            ++ clusterAdminKeys; # (2)
        }
    )
    hostsConfig;
in {
  inherit
    vpnModule
    vpnSecrets
    ;
}
