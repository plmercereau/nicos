{
  config,
  lib,
  pkgs,
  cluster,
  ...
}:
with lib; let
  vpn = config.settings.networking.vpn;
  servers = filterAttrs (_: config.lib.vpn.isServer) cluster.hosts;
  inherit (config.lib.vpn) machineIp;
in {
  config =
    mkIf vpn.enable
    {
      networking = {
        wg-quick.interfaces.${vpn.interface} = mkIf (!vpn.bastion.enable) {
          # Add an entry to systemd-resolved for each VPN server
          postUp = ''
            ${concatStringsSep "\n" (mapAttrsToList (_: cfg: ''
                resolvectl dns ${cfg.settings.networking.vpn.interface} ${machineIp cfg}:53
                resolvectl domain ${cfg.settings.networking.vpn.interface} ${vpn.domain}
              '')
              servers)}
          '';

          # When the VPN is down, remove the entries from systemd-resolved
          postDown = ''
            ${concatStringsSep "\n" (mapAttrsToList (_: cfg: ''
                resolvectl dns ${cfg.settings.networking.vpn.interface}
              '')
              servers)}

          '';
        };
      };
    };
}
