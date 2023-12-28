{
  config,
  modulesPath,
  pkgs,
  lib,
  ...
}: let
  cfg = config.services.samba;
in {
  # ! add user password with sudo smbpasswd -a <user>
  config = lib.mkIf cfg.enable {
    networking.firewall = {
      enable = true;
      allowPing = true;
      allowedTCPPorts = [
        5357 # wsdd
      ];
      allowedUDPPorts = [
        3702 # wsdd
      ];
    };

    services.samba-wsdd.enable = true; # make shares visible for windows 10 clients

    services.samba = {
      openFirewall = true;
      securityType = "user";
      # TODO parameter: local IPs - and vpn IPs
      extraConfig = ''
        server string = ${config.networking.hostName}
        netbios name = ${config.networking.hostName}
        workgroup = WORKGROUP
        security = user
        protocol_vers_map = 6
        vfs objects = fruit streams_xattr
        #use sendfile = yes
        #max protocol = smb2
        # note: localhost is the ipv6 localhost ::1
        hosts allow = 10.136.1.0/24 10.100.0.0/24 127.0.0.1 localhost
        hosts deny = 0.0.0.0/0
        guest account = nobody
        map to guest = bad user
      '';
    };
  };
}
