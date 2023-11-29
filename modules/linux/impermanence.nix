{
  config,
  lib,
  pkgs,
  ...
}: let
  impermanence = config.settings.impermanence.enable;
in {
  options.settings.impermanence = {
    # TODO not a good idea to make it as an option can it cannot be changed. Maybe sdImage.impermanence.enable?
    enable = lib.mkEnableOption "enable impermanence";
  };
  # ! Impermanence must be also reflected in the file system of each hardware type !
  config = {
    # * See: https://nixos.wiki/wiki/Impermanence
    environment.persistence."/nix/persist/system" = lib.mkIf impermanence {
      hideMounts = true;
      # this folder is where the files will be stored (don't put it in tmpfs)
      directories = [
        "/etc/nixos" # bind mounted from /nix/persist/system/etc/nixos to /etc/nixos
        # "/etc/NetworkManager"
        # "/var/log"
        "/var/lib"
      ];
      files = [
        #  NOTE: if you persist /var/log directory,  you should persist /etc/machine-id as well
        #  otherwise it will affect disk usage of log service
        # "/etc/nix/id_rsa" # recommended in the wiki, but not sure if it's needed
        "/etc/machine-id"
        "/etc/ssh/ssh_host_ed25519_key"
        "/etc/ssh/ssh_host_ed25519_key.pub"
        "/etc/ssh/ssh_host_rsa_key"
        "/etc/ssh/ssh_host_rsa_key.pub"
        # "/etc/NIXOS"
      ];
    };
  };
}
