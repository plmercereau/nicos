{
  config,
  lib,
  pkgs,
  ...
}: let
  hosts = config.cluster.hosts.config;
  isLinux = pkgs.hostPlatform.isLinux;
  wgIp = id: "${config.settings.wireguard.ipPrefix}.${builtins.toString id}";
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
        inherit (cfg.settings) id publicIP localIP sshPublicKey;
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
    # TODO fennec -> wireguard. fennec.home -> local network.
    environment.etc."ssh/ssh_config.d/300-hosts.conf" = {
      text = let
        # Get the SSID of the wifi network, if it exists
        # TODO use wc instead, and 1. wireguard, 2. local, 3. public
        getSSIDCommand =
          if isLinux
          then "iwgetid -r 2>/dev/null || true"
          else "/System/Library/PrivateFrameworks/Apple80211.framework/Resources/airport -I  | awk -F' SSID: '  '/ SSID: / {print $2}'";
      in
        builtins.concatStringsSep "\n" (lib.mapAttrsToList (
            name: cfg: let
              inherit (cfg.settings) id publicIP localIP;
            in ''
              ${
                # If the machine has a local IP, prefer it over the wireguard tunnel when on the local network
                lib.optionalString (localIP != null) ''
                  Match Originalhost ${name} Exec "(${getSSIDCommand}) | grep ${config.settings.localNetworkId}"
                    Hostname ${localIP}
                ''
              }
              Host ${name}
                HostName ${wgIp id}
            ''
          )
          hosts);
    };
  };
}
