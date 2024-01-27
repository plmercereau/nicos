{nixpkgs, ...}: let
  module = {
    config,
    cluster,
    lib,
    ...
  }:
    with lib; let
      inherit (cluster) projectRoot nixos darwin hosts;
      inherit (config.settings.services) kubernetes;
      upstream = findSingle null (cfg:
        cfg.nixpkgs.hostPlatform.isLinux
        && (let k8s = cfg.settings.services.kubernetes; in k8s.enable && k8s.fleet.enable && k8s.fleet.mode == "upstream"))
      hosts;
      k8s = config.settings.services.kubernetes;
    in
      mkIf (k8s.enable && k8s.fleet.enable && k8s.fleet.mode == "downstream" && (upstream != null)) {
        # Load the k3s root CA pem
        age.secrets.k3s-upstream-ca-pem.file = projectRoot + "/${nixos.path}/${upstream.networking.hostName}.k3s-ca.pem.age";
        settings.services.kubernetes.fleet.apiServerCAPath = age.secrets.k3s-upstream-ca-pem.path;
      };

  /*
  Accessible by:
  (1) the host that will run the k3s server
  (2) any downstream host, assuming the configured host is an upstream host
  (3) cluster admins
  */
  secrets = {
    adminKeys,
    hosts,
    nixos,
    ...
  }:
    with nixpkgs.lib; let
      nixosHosts = filterAttrs (_: cfg: cfg.nixpkgs.hostPlatform.isLinux) hosts;
      downstreamHosts = filterAttrs (_: cfg: cfg.settings.services.kubernetes.fleet.mode == "upstream") nixosHosts;
    in
      mapAttrs'
      (
        name: cfg:
          nameValuePair
          "${nixos.path}/${name}.k3s-ca.pem.age"
          {
            publicKeys =
              [cfg.settings.sshPublicKey] # (1)
              ++ (
                # (2)
                optionals
                (cfg.settings.services.kubernetes.fleet.mode == "upstream")
                (mapAttrsToList (_: downCfg: downCfg.settings.sshPublicKey) downstreamHosts)
              )
              ++ adminKeys; # (3)
          }
      )
      nixosHosts;
in {
  inherit
    module
    secrets
    ;
}
