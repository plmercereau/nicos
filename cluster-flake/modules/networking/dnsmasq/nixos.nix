{
  config,
  lib,
  pkgs,
  ...
}: let
  cfgWireguard = config.settings.wireguard;
  hosts = config.cluster.hosts.config;
  id = config.settings.id;

  servers = lib.filterAttrs (_: cfg: cfg.settings.wireguard.server.enable && cfg.settings.id != id) hosts;
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
      server = lib.mapAttrsToList (_:cfg: "${wgIp cfg.settings.id}@${cfgWireguard.interface}") servers;
    };
  };

  # Open the DNS port on the Wireguard interface if this is a Wireguard server
  networking.firewall.interfaces.${cfgWireguard.interface} = lib.mkIf cfgWireguard.server.enable {
    allowedTCPPorts = [53];
    allowedUDPPorts = [53];
  };

  # TODO public and local IPs too
  # TODO host.vpn -> wireguard, host.lan -> local IP, host.public -> public IP, host -> wireguard
  networking.hosts = lib.mkIf cfgWireguard.server.enable (
    lib.mapAttrs' (name: cfg: lib.nameValuePair (wgIp cfg.settings.id) [name "${name}.wg" "${name}.local"])
    hosts
  );
}
