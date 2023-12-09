{
  config,
  lib,
  pkgs,
  ...
}:
with lib; {
  options = {
    users.defaultUserShell = mkOption {
      type = types.either types.shellPackage types.path;
      default = "/sbin/nologin";
      example = literalExpression "pkgs.bashInteractive";
      description = lib.mdDoc "The user's shell.";
    };
  };
}
