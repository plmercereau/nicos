{
  config,
  lib,
  pkgs,
  options,
  ...
}:
with lib; {
  config = {
    system.stateVersion = "23.11";

    # Deactivate password login for root
    users.users.root.hashedPassword = "!";
    # Users can't change their own shell/password, it should happen in the Nix config
    users.mutableUsers = false;

    # Wheel group doesn't need a password so they can deploy using deploy-rs
    security.sudo.wheelNeedsPassword = false;

    nix = {
      # Required for deploy-rs to work, see https://github.com/serokell/deploy-rs/issues/25
      settings.trusted-users = ["@wheel"];
      package = pkgs.nixFlakes;
      extraOptions =
        lib.optionalString (config.nix.package == pkgs.nixFlakes)
        "experimental-features = nix-command flakes";
    };

    # Run unpatched dynamic binaries on NixOS.
    programs.nix-ld.enable = true;

    services = {
      # https://man7.org/linux/man-pages/man8/fstrim.8.html
      fstrim.enable = true;
      # # Avoid pulling in unneeded dependencies
      udisks2.enable = false;

      # NTP time sync.
      timesyncd = {
        enable = true;
        servers = mkDefault [
          "0.nixos.pool.ntp.org"
          "1.nixos.pool.ntp.org"
          "2.nixos.pool.ntp.org"
          "3.nixos.pool.ntp.org"
          "time.windows.com"
          "time.google.com"
        ];
      };

      htpdate = {
        enable = true;
        servers = ["www.kernel.org" "www.google.com" "www.cloudflare.com"];
      };
    };
  };
}
