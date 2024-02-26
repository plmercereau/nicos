{nixpkgs, ...}: {
  module = {
    config,
    cluster,
    lib,
    ...
  }:
    with lib; let
      inherit (cluster) projectRoot machinesPath;
      file = projectRoot + "/${machinesPath}/${config.networking.hostName}.vpn.age";
    in
      mkIf (pathExists file) {
        # Load Wireguard private key
        age.secrets.vpn.file = file;
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
