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

        This id will be translated into an IP when using the VPN module with `settings.networking.vpn.ipPrefix`.
      '';
      type = types.int;
      readOnly = true;
    };
  };
}
