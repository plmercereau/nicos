{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.settings.vpn;
  inherit (config.lib.vpn) clients bastion;
  inherit (bastion.settings.vpn.bastion) domain cidr;
in {
  config =
    mkIf (cfg.enable && !cfg.bastion.enable)
    {
      # Enable resolved for custom DNS configuration
      services.resolved.enable = mkForce true;
      # networking.networkmanager.dns = "systemd-resolved";
      # TODO weird stuff happening with resolved:
      # when running 'resolvectl' after a reboot:
      # Failed to get global data: Unit dbus-org.freedesktop.resolve1.service not found.
      # ... but it works after a new system activation
      # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/system/boot/resolved.nix
      # https://discourse.nixos.org/t/networkmanager-service-resets-my-resolv-conf-configuration/21072/6
      # https://discourse.nixos.org/t/occasional-dns-problems/35824/6
      # https://github.com/search?q=repo%3ANixOS%2Fnixpkgs+dbus-org.freedesktop.resolve1.service&type=issues
      # https://discourse.nixos.org/t/how-to-make-systemd-resolved-and-mdns-work-together/10910/2

      networking = {
        wg-quick.interfaces.wg0 = {
          # Add an entry to systemd-resolved for each VPN server
          postUp = ''
            resolvectl dns wg0 ${bastion.lib.vpn.ip}:53
            resolvectl domain wg0 ${domain}
          '';

          # When the VPN is down, remove the entries from systemd-resolved
          postDown = ''
            resolvectl dns wg0
          '';

          peers = [
            {
              inherit (bastion.settings.vpn) publicKey;
              allowedIPs = [cidr];
              endpoint = "${bastion.settings.publicIP}:${builtins.toString bastion.settings.vpn.bastion.port}";
              # Send keepalives every 25 seconds. Important to keep NAT tables alive.
              persistentKeepalive = 25;
            }
          ];
        };
      };
    };
}
