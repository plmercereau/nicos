{
  config,
  lib,
  pkgs,
  ...
}: let
  domain = "local"; # TODO configurable. See Linux config too.
  wgIp = id: "${config.settings.wireguard.ipPrefix}.${builtins.toString id}"; # TODO used in four modules -> move to a common place
in {
  services.dnsmasq = {
    enable = true;
    bind = "127.0.0.1"; # ! Hack: would break the services.dnsmasq.addresses option, but that's fine as we don't use it
    port = 53; # default
  };

  environment.etc."dnsmasq.conf".text = let
    cfgWireguard = config.settings.wireguard;
    servers = lib.filterAttrs (_: cfg: cfg.settings.wireguard.server.enable) config.cluster.hosts.config;
  in ''
    port=53
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (_: cfg: "server=/.${domain}/${wgIp cfg.settings.id}") servers)}
  '';

  environment.etc."resolver/${domain}".text = ''
    port 53
    nameserver 127.0.0.1
    nameserver ::1
  '';
}
