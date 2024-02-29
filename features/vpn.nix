{nixpkgs, ...}: {
  module = {
    config,
    cluster,
    lib,
    ...
  }:
    with lib; {
      age.secrets = {
        tailscale-host.file = cluster.projectRoot + "/tailscale-host.age";
        tailscale-cluster = mkIf config.settings.kubernetes.enable {
          file = cluster.projectRoot + "/tailscale-cluster.age";
        };
      };
      services.tailscale = {
        enable = true;
        authKeyFile = config.age.secrets.tailscale-host.path;
        extraUpFlags = [
          "--advertise-tags=tag:host"
          "--hostname=${config.networking.hostName}"
        ];
      };
    };

  /*
  Accessible by:
  (1) the host that uses the related secret
  (2) cluster admins
  */
  secrets = {
    adminKeys,
    hosts,
    machinesPath,
    ...
  }:
    with nixpkgs.lib; let
      publicKeys =
        (mapAttrsToList (name: cfg: cfg.settings.sshPublicKey) hosts) # (1)
        ++ adminKeys; # (2)
    in {
      "tailscale-host.age" = {inherit publicKeys;};
      "tailscale-cluster.age" = {inherit publicKeys;};
    };
}
