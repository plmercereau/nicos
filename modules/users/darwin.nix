{
  config,
  lib,
  pkgs,
  ...
}:
with lib; {
  options = {
    # ! Define the same option as in NixOS
    users.defaultUserShell = mkOption {
      type = types.either types.shellPackage types.path;
      default = "/sbin/nologin";
      example = literalExpression "pkgs.bashInteractive";
      description = mdDoc "The user's shell.";
    };
  };

  config = {
    # Enable sudo authentication with Touch ID
    # See: https://daiderd.com/nix-darwin/manual/index.html#opt-security.pam.enableSudoTouchIdAuth
    security.pam.enableSudoTouchIdAuth = true;

    # * See: https://github.com/LnL7/nix-darwin/blob/master/tests/system-defaults-write.nix
    system.defaults = {
      loginwindow.GuestEnabled = false;
    };
  };
}
