{
  config,
  lib,
  pkgs,
  cluster,
  ...
}:
with lib; let
  vpn = config.settings.networking.vpn;
  inherit (cluster) hosts;
  inherit (config.lib.vpn) ip isServer machineIp;
  servers = filterAttrs (_: isServer) hosts;
in {
  config = mkIf vpn.enable {
    networking.wg-quick.interfaces.${vpn.interface} = {
      postUp = ''
        ${concatStringsSep "\n" (mapAttrsToList (_: cfg: ''
            # Add the route to the VPN network
            mkdir -p /etc/resolver
            cat << EOF > /etc/resolver/${vpn.domain}
            port 53
            domain ${vpn.domain}
            search ${vpn.domain}
            nameserver ${machineIp cfg}
            EOF
          '')
          servers)}
      '';

      postDown = ''
        ${concatStringsSep "\n" (mapAttrsToList (_: cfg: ''
            rm -f /etc/resolver/${vpn.domain}
          '')
          servers)}

      '';
    };
  };
}
