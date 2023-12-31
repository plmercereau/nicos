{
  lib,
  config,
  ...
}:
with lib; {
  options = {
    settings.id = mkOption {
      description = ''
        Id of the machine. Each machine must have an unique value.

        This id will be translated into an IP with `settings.networking.vpn.ipPrefix` when using the VPN module.
      '';
      type = types.int;
      readOnly = true;
    };
  };
}
