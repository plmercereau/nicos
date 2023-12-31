{
  config,
  lib,
  pkgs,
  cluster,
  ...
}: let
  domain = "local"; # TODO should be configurable. See Linux config too.
  vpn = config.settings.networking.vpn;
  inherit (cluster) hosts;
  servers = lib.filterAttrs (_: cfg: cfg.settings.networking.vpn.bastion.enable) hosts;
  inherit (config.lib.ext_lib) idToVpnIp;
in {
  config = lib.mkIf vpn.enable {
    services.dnsmasq = {
      enable = true;
      bind = "127.0.0.1"; # ! Hack: would break the services.dnsmasq.addresses option, but that's fine as we don't use it
      port = 53; # default
    };

    environment.etc."dnsmasq.conf".text = ''
      port=53
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (_: cfg: "server=/.${domain}/${idToVpnIp}") servers)}
    '';

    environment.etc."resolver/${domain}".text = ''
      port 53
      nameserver 127.0.0.1
      nameserver ::1
    '';
  };
}
