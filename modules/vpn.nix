{
  config,
  cluster,
  lib,
  ...
}:
with lib; {
  options.settings = {
    tailnet = mkOption {
      type = types.str;
      description = "The Tailscale network to join";
    };
  };

  config = {
    services.tailscale = {
      enable = true;
      extraUpFlags = [
        "--advertise-tags=tag:host"
        "--hostname=${config.networking.hostName}"
      ];
    };
  };
}
