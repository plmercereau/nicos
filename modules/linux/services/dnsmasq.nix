{
  config,
  lib,
  pkgs,
  ...
}: let
  cfgWireguard = config.settings.wireguard;
  hosts = config.settings.hosts;
  host = hosts."${config.networking.hostName}";
  servers = lib.filterAttrs (_: cfg: cfg.wg.server.enable) hosts;
  domain = "local"; # TODO make it configurable as an option. See Darwin config too
  wgIp = id: "${cfgWireguard.ipPrefix}.${builtins.toString id}";
in {
  services.dnsmasq = {
    enable = true;
    alwaysKeepRunning = true;
    resolveLocalQueries = true;
    settings = {
      inherit domain;
      local = "/${domain}/";
      interface = ["lo"];
      server = lib.mapAttrsToList (_:cfg: "${wgIp cfg.id}@${cfgWireguard.interface}") (lib.filterAttrs (_: cfg: cfg.id != host.id) servers);
    };
  };

  # Open the DNS port on the Wireguard interface if this is a Wireguard server
  networking.firewall.interfaces."${cfgWireguard.interface}" = lib.mkIf host.wg.server.enable {
    allowedTCPPorts = [53];
    allowedUDPPorts = [53];
  };
}
