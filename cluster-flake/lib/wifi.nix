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

  wifiModule = {
    projectRoot,
    wifi,
    ...
  }: ({config, ...}: {
    # Load wifi PSKs
    # Only mount wifi passwords if wireless is enabled
    age.secrets.wifi = lib.mkIf wifi.enable {
      file = projectRoot + "/${wifi.path}/psk.age";
    };

    # ? check if list.json and psk.age exists. If not, create a warning instead of an error?
    # Only configure default wifi if wireless is enabled
    networking = lib.mkIf wifi.enable {
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
  });

  /*
  Accessible by:
  (1) hosts with wifi enabled (1)
  (2) cluster admins
  */
  wifiSecret = {
    wifi,
    hostsConfig,
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
        hostsConfig;
    };
in {
  inherit
    wifiModule
    wifiSecret
    ;
}
