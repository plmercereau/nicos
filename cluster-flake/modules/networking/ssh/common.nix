{
  config,
  lib,
  pkgs,
  ...
}: let
  hosts = config.cluster.hosts.config;
  isLinux = pkgs.hostPlatform.isLinux;
  vpn = config.settings.networking.vpn;
  inherit (config.lib.ext_lib) wgIp;
in {
  options.settings = with lib; {
    sshPublicKey = mkOption {
      description = "SSH public key of the machine";
      type = types.str;
    };
  };

  config = {
    # Load SSH known hosts
    programs.ssh.knownHosts =
      lib.mapAttrs (name: cfg: let
        inherit (cfg.settings) id sshPublicKey;
        inherit (cfg.settings.networking) publicIP localIP;
      in {
        hostNames =
          [(wgIp id)]
          ++ lib.optional (publicIP != null) publicIP
          ++ lib.optional (localIP != null) localIP;
        publicKey = sshPublicKey;
      })
      hosts;

    # Configure ssh host aliases
    # TODO simplify/remove, now that we have dnsmasq on evey machine
    # TODO fennec -> Wireguard. fennec.home -> local network.
    environment.etc."ssh/ssh_config.d/300-hosts.conf" = {
      text = let
        # Get the SSID of the wifi network, if it exists
        # TODO use wc instead, and 1. Wireguard, 2. local, 3. public
        getSSIDCommand =
          if isLinux
          then "iwgetid -r 2>/dev/null || true"
          else "/System/Library/PrivateFrameworks/Apple80211.framework/Resources/airport -I  | awk -F' SSID: '  '/ SSID: / {print $2}'";
      in
        builtins.concatStringsSep "\n" (lib.mapAttrsToList (
            name: cfg: let
              inherit (cfg.settings) id;
              inherit (cfg.settings.networking) publicIP localIP;
            in
              # If the machine has a local IP, prefer it over the Wireguard tunnel when on the local network
              lib.optionalString (localIP != null) ''
                Match Originalhost ${name} Exec "(${getSSIDCommand}) | grep ${config.settings.networking.localNetworkId}"
                  Hostname ${localIP}
              ''
              + lib.optionalString (vpn.enable) ''
                Host ${name}
                  HostName ${wgIp id}
              ''
          )
          hosts);
    };
  };
}
