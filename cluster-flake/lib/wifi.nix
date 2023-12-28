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
    inherit (cluster) projectRoot wifi;
    # TODO only enable on machines actually using wifi!!!
    enable = config.nixpkgs.hostPlatform.isLinux && wifi.enable;
  in {
    # Load wifi PSKs
    # Only mount wifi passwords if wireless is enabled
    age.secrets.wifi = lib.mkIf enable {
      file = projectRoot + "/${wifi.path}/psk.age";
    };

    # ? check if list.json and psk.age exists. If not, create a warning instead of an error?
    # Only configure default wifi if wireless is enabled
    networking = lib.mkIf enable {
      wireless = {
        environmentFile = config.age.secrets.wifi.path;
        networks = let
          list = lib.importJSON (projectRoot + "/${wifi.path}/list.json");
        in
          builtins.listToAttrs (builtins.map (name: {
              inherit name;
              value = {psk = "@${name}@";};
            })
            list);
      };
    };
  };

  /*
  Accessible by:
  (1) hosts with wifi enabled (1)
  (2) cluster admins
  */
  secrets = {
    wifi,
    hosts,
    adminKeys,
    ...
  }:
    lib.optionalAttrs wifi.enable {
      "${wifi.path}/psk.age".publicKeys =
        lib.foldlAttrs (
          acc: _: cfg:
            acc
            ++ (
              # (1)
              lib.optional (
                builtins.hasAttr "wireless" cfg.networking # cfg.networking.wireless is not defined on darwin
                && cfg.networking.wireless.enable
              )
              cfg.settings.sshPublicKey
            )
        )
        # (2)
        adminKeys
        hosts;
    };
in {
  inherit
    module
    secrets
    ;
}
