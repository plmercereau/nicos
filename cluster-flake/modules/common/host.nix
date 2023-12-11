{lib, ...}: {
  options.settings = with lib; {
    id = mkOption {
      description = "Id of the machine, that will be translated into an IP";
      type = types.int;
      readOnly = true;
    };
  };
}
