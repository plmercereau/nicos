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

    publicDomain = mkOption {
      description = "Public domain of the machine";
      type = types.str;
      default = "public";
    };

    localIP = mkOption {
      description = "IP of the machine in the local network";
      type = types.nullOr types.str;
      default = null;
    };

    localDomain = mkOption {
      description = "Local domain of the machine";
      type = types.str;
      default = "lan";
    };
  };
  config = {
    # * We public and local IPs to /etc/hosts as "<ip> <hostname>.<public-domain>" and "<ip> <hostname>.<local-domain>"
    # * But we don't add "<ip> <hostname>" to give priority to the ip from the VNP DNS
    networking.extraHosts = let
      withPublicIP = filterAttrs (_: cfg: cfg.settings.networking.publicIP != null) hosts;
      withLocalIP = filterAttrs (_: cfg: cfg.settings.networking.localIP != null) hosts;
    in ''
      ${concatStringsSep "\n" (mapAttrsToList (name: cfg: let
        inherit (cfg.settings.networking) publicIP publicDomain;
      in "${publicIP} ${name}.${publicDomain}")
      withPublicIP)}
      ${concatStringsSep "\n" (mapAttrsToList (name: cfg: let
        inherit (cfg.settings.networking) localIP localDomain;
      in "${localIP} ${name}.${localDomain}")
      withLocalIP)}
    '';
  };
}
