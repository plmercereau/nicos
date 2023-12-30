{lib, ...}: {
  options.settings.networking = with lib; {
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
