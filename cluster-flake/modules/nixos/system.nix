{
  config,
  lib,
  pkgs,
  ...
}: {
  system.stateVersion = "23.11";

  # Deactivate password login for root
  users.users.root.hashedPassword = "!";
  # Users can't change their own shell/password, it should happen in the Nix config
  users.mutableUsers = false;

  # Wheel group doesn't need a password so they can deploy using deploy-rs
  security.sudo.wheelNeedsPassword = false;

  # Enable the same way of configuring ssh on NixOS as on Darwin
  programs.ssh.extraConfig = ''
    Include /etc/ssh/ssh_config.d/*
  '';
}
