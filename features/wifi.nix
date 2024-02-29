{
  agenix,
  deploy-rs,
  disko,
  home-manager,
  impermanence,
  nixpkgs,
  srvos,
  ...
}: {
  module = {
    config,
    cluster,
    lib,
    ...
  }:
    with lib; let
      inherit (cluster) projectRoot wifi;
      # Enable this module only the wifi feature is enabled and this machine has wireless networking enabled
      enable = wifi.enable && config.networking.wireless.enable;
    in
      mkIf enable {
        # Load wifi PSKs
        age.secrets.wifi.file = projectRoot + "/${wifi.path}/psk.age";
        # Enables `wpa_supplicant` on boot.
        systemd.services.wpa_supplicant.wantedBy = mkOverride 10 ["default.target"];
        # ? check if list.json and psk.age exists. If not, create a warning instead of an error?
        # Only configure default wifi if wireless is enabled
        networking.wireless = {
          environmentFile = config.age.secrets.wifi.path;
          networks = let
            list = importJSON (projectRoot + "/${wifi.path}/list.json");
          in
            builtins.listToAttrs (builtins.map (name: {
                inherit name;
                value = {psk = "@${name}@";};
              })
              list);
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
    with nixpkgs.lib;
      optionalAttrs wifi.enable {
        "${wifi.path}/psk.age".publicKeys =
          foldlAttrs (
            acc: _: cfg:
              acc
              ++ (optional cfg.networking.wireless.enable cfg.settings.sshPublicKey) # (1)
          )
          # (2)
          adminKeys
          hosts;
      };
}
