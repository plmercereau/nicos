{
  config,
  lib,
  pkgs,
  ...
}:
with lib; {
  # See: https://git.sr.ht/~r-vdp/resilientOS/tree/master/item/modules/sshd.nix
  options.settings.ssh = {
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

    # Enable the same way of configuring ssh on NixOS as on Darwin
    programs.ssh.extraConfig = ''
      Include /etc/ssh/ssh_config.d/*
    '';
  };
}
