{
  config,
  lib,
  pkgs,
  cluster,
  ...
}: let
  inherit (cluster) hosts;
  vpn = config.settings.networking.vpn;
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
        inherit (cfg.settings) sshPublicKey;
        inherit (cfg.settings.networking) publicIP localIP;
      in {
        hostNames =
          lib.optionals cfg.settings.networking.vpn.enable [cfg.lib.vpn.ip cfg.networking.hostName "${cfg.networking.hostName}.${cfg.settings.networking.vpn.domain}"]
          ++ lib.optional (publicIP != null) publicIP
          ++ lib.optional (localIP != null) localIP;
        publicKey = sshPublicKey;
      })
      hosts;

    # Configure ssh host aliases
    # TODO deactivated for now until we find a better way to "ping" machines (nc doesn't hang up when the machine is not available)
    # TODO: darwin: nc -G SECONDS works, but not on linux...
    # environment.etc."ssh/ssh_config.d/300-hosts.conf" = {
    #   text = builtins.concatStringsSep "\n" (lib.mapAttrsToList (
    #       name: cfg: let
    #         inherit (cfg.settings.networking) publicIP localIP;
    #       in
    #         # Use the local IP if it is available
    #         lib.optionalString (localIP != null) ''
    #           Match Originalhost ${name} Exec "(nc -z ${localIP} 22 2>/dev/null)"
    #             Hostname ${localIP}
    #         ''
    #         +
    #         # Otherwise use the public IP if available. T
    #         lib.optionalString (publicIP != null) ''
    #           Match Originalhost ${name} Exec "(nc -z ${publicIP} 22 2>/dev/null)"
    #             Hostname ${publicIP}
    #         ''
    #       # If no match is found, it will use the original host name, that should be the VPN IP
    #     )
    #     hosts);
    # };
    environment.etc."ssh/ssh_config.d/300-hosts.conf" = {
      text = builtins.concatStringsSep "\n" (lib.mapAttrsToList (
          name: cfg: let
            inherit (cfg.settings.networking) publicIP publicDomain localIP localDomain;
          in
            # Use the local IP if it is available
            lib.optionalString (localIP != null) ''
              Match Originalhost ${name}.${localDomain}
                Hostname ${localIP}
            ''
            +
            # Use the public IP if available. T
            lib.optionalString (publicIP != null) ''
              Match Originalhost ${name}.${publicDomain}
                Hostname ${publicIP}
            ''
        )
        hosts);
    };
  };
}
