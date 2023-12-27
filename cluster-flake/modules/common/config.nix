{
  lib,
  config,
  ...
}:
with lib; {
  options = {
    settings.id = mkOption {
      description = "Id of the machine, that will be translated into an IP";
      type = types.int;
      readOnly = true;
    };
  };
}
