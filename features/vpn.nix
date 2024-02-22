{nixpkgs, ...}: {
  module = {
    config,
    cluster,
    lib,
    ...
  }:
    with lib; let
      inherit (cluster) projectRoot machinesPath;
      vpn = config.settings.vpn;
    in
      mkIf vpn.enable {
        # Load Wireguard private key
        age.secrets.vpn.file = projectRoot + "/${machinesPath}/${config.networking.hostName}.vpn.age";
        # Path to the private key file.
        networking.wg-quick.interfaces.wg0.privateKeyFile = config.age.secrets.vpn.path;
      };

  /*
  Accessible by:
  (1) the host that uses the related Wireguard secret
  (2) cluster admins
  */
  secrets = {
    adminKeys,
    hosts,
    machinesPath,
    ...
  }:
    with nixpkgs.lib;
      mapAttrs'
      (
        name: cfg:
          nameValuePair
          "${machinesPath}/${name}.vpn.age"
          {
            publicKeys =
              [cfg.settings.sshPublicKey] # (1)
              ++ adminKeys; # (2)
          }
      )
      hosts;
}
