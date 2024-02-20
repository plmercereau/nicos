{
  lib,
  cluster,
  config,
  ...
}:
with lib; let
  inherit (cluster) hosts;
  cfg = config.settings;
in {
  options.settings = {
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
  };
  config = {
    networking.domain = "local";

    #! From svros: https://github.com/search?q=repo%3Anix-community%2Fsrvos%20NetworkManager-wait-online&type=code
    # The notion of "online" is a broken concept
    # https://github.com/systemd/systemd/blob/e1b45a756f71deac8c1aa9a008bd0dab47f64777/NEWS#L13
    systemd.services.NetworkManager-wait-online.enable = false;
    systemd.network.wait-online.enable = false;

    # * We public and local IPs to /etc/hosts as "<ip> <hostname>.<public-domain>" and "<ip> <hostname>.<local-domain>"
    # * But we don't add "<ip> <hostname>" to give priority to the ip from the VNP DNS
    networking.extraHosts = let
      withPublicIP = filterAttrs (_: machine: machine.settings.publicIP != null) hosts;
      withLocalIP = filterAttrs (_: machine: machine.settings.localIP != null) hosts;
    in ''
      ${concatStringsSep "\n" (mapAttrsToList (name: machine: "${machine.settings.publicIP} ${name}.${cfg.publicDomain}")
          withPublicIP)}
      ${concatStringsSep "\n" (mapAttrsToList (name: machine: "${machine.settings.localIP} ${name}.${config.networking.domain}")
          withLocalIP)}
    '';
  };
}
