{
  config,
  lib,
  pkgs,
  ...
}: {
  nix.configureBuildUsers = true; # Allow nix-darwin to build users

  # Enable sudo authentication with Touch ID
  # See: https://daiderd.com/nix-darwin/manual/index.html#opt-security.pam.enableSudoTouchIdAuth
  security.pam.enableSudoTouchIdAuth = true;

  # * See: https://github.com/LnL7/nix-darwin/blob/master/tests/system-defaults-write.nix
  system.defaults = {
    loginwindow.GuestEnabled = false;
  };
}
