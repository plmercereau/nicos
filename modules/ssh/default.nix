{
  config,
  lib,
  pkgs,
  cluster,
  ...
}:
with lib; let
  inherit (cluster) hosts;
in {
  options.settings = {
    sshPublicKey = mkOption {
      description = ''
        SSH public key of the machine.
              
        This option is required to decode the secrets defined in the main features like users, wireless networks, vpn, etc.'';
      type = types.str;
    };

    # See: https://git.sr.ht/~r-vdp/resilientOS/tree/master/item/modules/sshd.nix
    ssh = {
      fail2ban.enable = mkOption {
        description = ''
          Enable fail2ban to block SSH brute force attacks.

          By default, Fail2ban is enabled if sshguard is disabled.
        '';
        type = types.bool;
        default = !config.settings.ssh.sshguard.enable;
      };
      sshguard.enable = mkOption {
        description = "Enable sshguard to block SSH brute force attacks.";
        type = types.bool;
        default = true;
      };
    };
  };

  # OpenSSH is forced to have an empty `wantedBy` on the installer system[1], this won't allow it
  # to be automatically started. Override it with the normal value.
  # [1] https://github.com/NixOS/nixpkgs/blob/9e5aa25/nixos/modules/profiles/installation-device.nix#L76
  # systemd.services.sshd.wantedBy = lib.mkOverride 40 [ "multi-user.target" ];
  config = {
    services = {
      # Enable OpenSSH on every machine
      openssh = {
        enable = true;
        settings = {
          PermitRootLogin = mkDefault "no";
          X11Forwarding = false;
          KbdInteractiveAuthentication = false;
        };
        # passwordAuthentication = false;
        allowSFTP = true;
      };

      fail2ban = mkIf config.settings.ssh.fail2ban.enable {
        inherit (config.settings.ssh.fail2ban) enable;
        jails.ssh-iptables = mkForce "";
        jails.ssh-iptables-extra = ''
          action   = iptables-multiport[name=SSH, port="${
            concatMapStringsSep "," toString config.services.openssh.ports
          }", protocol=tcp]
          maxretry = 3
          findtime = 3600
          bantime  = 3600
          filter   = sshd[mode=extra]
        '';
      };

      sshguard = mkIf config.settings.ssh.sshguard.enable {
        inherit (config.settings.ssh.sshguard) enable;
        attack_threshold = 80;
        blocktime = 10 * 60;
        detection_time = 7 * 24 * 60 * 60;
        whitelist = ["localhost"];
      };
    };

    # Load SSH known hosts
    programs.ssh.knownHosts =
      mapAttrs (name: cfg: let
        inherit (cfg.settings) sshPublicKey publicIP localIP vpn;
      in {
        hostNames =
          optionals vpn.enable [cfg.lib.vpn.ip name]
          ++ optional (publicIP != null) publicIP
          ++ optional (localIP != null) localIP;
        publicKey = sshPublicKey;
      })
      hosts;

    # Configure ssh host aliases
    # TODO deactivated for now until we find a better way to "ping" machines (nc doesn't hang up when the machine is not available)
    # nc -G SECONDS works on mac, but not on linux...
    # environment.etc."ssh/ssh_config.d/300-hosts.conf" = {
    #   text = builtins.concatStringsSep "\n" (mapAttrsToList (
    #       name: cfg: let
    #         inherit (cfg.networking) publicIP localIP;
    #       in
    #         # Use the local IP if it is available
    #         optionalString (localIP != null) ''
    #           Match Originalhost ${name} Exec "(nc -z ${localIP} 22 2>/dev/null)"
    #             Hostname ${localIP}
    #         ''
    #         +
    #         # Otherwise use the public IP if available. T
    #         optionalString (publicIP != null) ''
    #           Match Originalhost ${name} Exec "(nc -z ${publicIP} 22 2>/dev/null)"
    #             Hostname ${publicIP}
    #         ''
    #       # If no match is found, it will use the original host name, that should be the VPN IP
    #     )
    #     hosts);
    # };

    programs.ssh.extraConfig = builtins.concatStringsSep "\n" (mapAttrsToList (
        name: cfg: let
          inherit (cfg.settings) publicIP localIP;
        in
          # Use the local IP if it is available
          optionalString (localIP != null) ''
            Match Originalhost ${name}.${config.networking.domain}
              Hostname ${localIP}
          ''
          +
          # Use the public IP if available. T
          optionalString (publicIP != null) ''
            Match Originalhost ${name}.${config.settings.publicDomain}
              Hostname ${publicIP}
          ''
      )
      hosts);
  };
}
