{
  config,
  lib,
  pkgs,
  ...
}: let
  hosts = config.settings.hosts;
  host = hosts."${config.networking.hostName}";
  isLinux = pkgs.hostPlatform.isLinux;
  ipWireguard = id: "${config.settings.wireguard.ipPrefix}.${builtins.toString id}";
in {
  options.settings = with lib; {
    localNetworkId = mkOption {
      description = "SSID of the local network where the machines usually lies";
      type = types.str;
    };
  };

  config = {
    # Load SSH known hosts
    programs.ssh.knownHosts =
      lib.mapAttrs (name: cfg: {
        hostNames =
          [(ipWireguard cfg.id)]
          ++ lib.optional (cfg.publicIP != null) cfg.publicIP
          ++ lib.optional (cfg.localIP != null) cfg.localIP;
        publicKey = cfg.sshPublicKey;
      })
      hosts;

    # Configure ssh host aliases
    environment.etc."ssh/ssh_config.d/300-hosts.conf" = {
      text = let
        # Get the SSID of the wifi network, if it exists
        getSSIDCommand =
          if isLinux
          then "iwgetid -r 2>/dev/null || true"
          else "/System/Library/PrivateFrameworks/Apple80211.framework/Resources/airport -I  | awk -F' SSID: '  '/ SSID: / {print $2}'";
      in
        builtins.concatStringsSep "\n" (lib.mapAttrsToList (
            name: cfg: ''
              ${
                # If the machine has a local IP, prefer it over the wireguard tunnel when on the local network
                lib.optionalString (cfg.localIP != null) ''
                  Match Originalhost ${name} Exec "(${getSSIDCommand}) | grep ${config.settings.localNetworkId}"
                    Hostname ${cfg.localIP}
                ''
              }
              Host ${name}
                HostName ${ipWireguard cfg.id}
            ''
          )
          hosts);
    };
  };
}
