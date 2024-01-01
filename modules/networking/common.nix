{
  lib,
  cluster,
  ...
}:
with lib; let
  inherit (cluster) hosts;
in {
  options.settings.networking = {
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
  config = {
    # * We public and local IPs to /etc/hosts as "<ip> <hostname>.public" and "<ip> <hostname>.lan"
    # * But we don't add "<ip> <hostname>" to give priority to the ip from the VNP DNS
    networking.extraHosts = let
      withPublicIP = filterAttrs (_: cfg: cfg.settings.networking.publicIP != null) hosts;
      withLocalIP = filterAttrs (_: cfg: cfg.settings.networking.localIP != null) hosts;
    in ''
      ${concatStringsSep "\n" (mapAttrsToList (name: cfg: "${cfg.settings.networking.publicIP} ${name}.public") withPublicIP)}
      ${concatStringsSep "\n" (mapAttrsToList (name: cfg: "${cfg.settings.networking.localIP} ${name}.lan") withLocalIP)}
    '';
  };
}
