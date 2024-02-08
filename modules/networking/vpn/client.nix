{
  config,
  lib,
  pkgs,
  cluster,
  ...
}:
with lib; let
  vpn = config.settings.networking.vpn;
  servers = filterAttrs (_: cfg: cfg.lib.vpn.isServer) cluster.hosts;
in {
  config =
    mkIf (vpn.enable && !vpn.bastion.enable)
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
        wg-quick.interfaces.${vpn.interface} = {
          # Add an entry to systemd-resolved for each VPN server
          postUp = ''
            ${concatStringsSep "\n" (mapAttrsToList (_: cfg: let
                serverCfg = cfg.settings.networking.vpn;
              in ''
                resolvectl dns ${serverCfg.interface} ${cfg.lib.vpn.ip}:53
                resolvectl domain ${serverCfg.interface} ${serverCfg.domain}
              '')
              servers)}
          '';

          # When the VPN is down, remove the entries from systemd-resolved
          postDown = ''
            ${concatStringsSep "\n" (mapAttrsToList (_: cfg: ''
                resolvectl dns ${cfg.settings.networking.vpn.interface}
              '')
              servers)}

          '';
        };
      };
    };
}
