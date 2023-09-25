{
  config,
  lib,
  ...
}: let
  cfgTunnel = config.settings.tunnel;
  cfgBastion = config.settings.bastion;
in {
  config = {
    settings.bastion.host = "bastion";
    age.secrets.tunnel = lib.mkIf cfgTunnel.enable {
      file = ./tunnel.age;
      mode = "400";
      owner = cfgBastion.user.name;
    };
    settings.bastion.user.privateKeyFile = lib.mkIf cfgTunnel.enable config.age.secrets.tunnel.path;
  };
}
