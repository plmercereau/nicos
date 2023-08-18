{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.settings.server;
in
{
  options.settings = {
    server = {
      enable = mkEnableOption "is this machine a server";
    };
  };

  config = mkIf cfg.enable {

    # Enable OpenSSH out of the box.
    services.sshd.enable = true;
    # OpenSSH is forced to have an empty `wantedBy` on the installer system[1], this won't allow it
    # to be automatically started. Override it with the normal value.
    # [1] https://github.com/NixOS/nixpkgs/blob/9e5aa25/nixos/modules/profiles/installation-device.nix#L76
    # systemd.services.sshd.wantedBy = lib.mkOverride 40 [ "multi-user.target" ];
  };
}

