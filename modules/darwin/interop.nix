{
  config,
  options,
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
    # "fonts" renamed to "packages" in nixos, but not in nix-darwin
    fonts.packages = options.fonts.fonts;
  };
}
