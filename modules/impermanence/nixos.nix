{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.settings.system.impermanence;
in {
  options.settings.system.impermanence = {
    # ? maybe not a good idea to make it as an option as it can hardly be changed.
    enable = lib.mkEnableOption "impermanence";
    persistentSystemPath = lib.mkOption {
      description = "Path to where the persisted part of the system lies";
      default = "/nix/persist/system";
      type = lib.types.str;
    };
    # TODO limit log size with logrotate (create a logrotate module)
  };

  # ! Impermanence must be also reflected in the file system of each hardware type !
  config = {
    settings.system.diskSwap.enable = false;

    age.identityPaths = lib.mkIf cfg.enable ["${cfg.systemPath}/etc/ssh/ssh_host_ed25519_key"];

    # * See: https://nixos.wiki/wiki/Impermanence
    environment.persistence.${cfg.systemPath} = lib.mkIf cfg.enable {
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
        # "/nix-path-registration" # ! doesn't work because it's not available at postBootCommands time (impermanence uses systemd and postBootCommands runs before systemd)
      ];
    };
  };
}
