# TODO find a better name e.g. config ?
{lib, ...}: {
  options.settings = with lib; {
    localNetworkId = mkOption {
      description = "SSID of the local network where the machines usually lies";
      type = types.str;
    };

    publicIP = mkOption {
      description = "Public IP of the machine";
      type = types.nullOr types.str;
      default = null;
    };

    localIP = mkOption {
      description = "IP of the machine in the local network";
      type = types.nullOr types.str;
      default = null;
    };
  };
}
