# Common settings to every host
# TODO put the "pilou" user here
{
  config,
  lib,
  ...
}: {
  # TODO move elsewhere e.g. in the flake
  age.secrets.wireguard.file = ./hosts + "/${config.networking.hostName}.wg.age";
}
