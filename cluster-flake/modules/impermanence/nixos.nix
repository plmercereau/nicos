{
  config,
  lib,
  pkgs,
  ...
}: let
  impermanence = config.settings.impermanence.enable;
  systemPath = config.settings.impermanence.persistentSystemPath;
in {
  options.settings.impermanence = {
    # ? maybe not a good idea to make it as an option as it can hardly be changed.
    enable = lib.mkEnableOption "enable impermanence";
    persistentSystemPath = lib.mkOption {
      description = "Path to where the persisted part of the system lies";
      default = "/nix/persist/system";
      type = lib.types.str;
    };
    # TODO limit log size with logrotate (create a logrotate module)
  };

  # ! Impermanence must be also reflected in the file system of each hardware type !
  config = {
    age.identityPaths = lib.mkIf impermanence ["${systemPath}/etc/ssh/ssh_host_ed25519_key"];

    # * See: https://nixos.wiki/wiki/Impermanence
    environment.persistence.${systemPath} = lib.mkIf impermanence {
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
