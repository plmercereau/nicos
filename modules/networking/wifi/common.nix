{lib, ...}: {
  options.settings.networking = with lib; {
    wireless = {
      localNetworkId = mkOption {
        description = "SSID of the local network where the machines usually lies";
        type = types.nullOr types.str;
        default = null;
      };
    };
  };
}
