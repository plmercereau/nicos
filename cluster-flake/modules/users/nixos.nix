{
  config,
  lib,
  pkgs,
  ...
}: {
  # Deactivate password login for root
  users.users.root.hashedPassword = "!";
  # Users can't change their own shell/password, it should happen in the Nix config
  users.mutableUsers = false;

  # Wheel group doesn't need a password so they can deploy using deploy-rs
  security.sudo.wheelNeedsPassword = false;
}
