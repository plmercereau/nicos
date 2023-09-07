{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  inherit (config.lib) ext_lib;
  isDarwin = pkgs.hostPlatform.isDarwin;
  isLinux = pkgs.hostPlatform.isLinux;
  cfg = config.settings.users;
  defaultDomain = hostName:
    if hostName == null
    then "localhost"
    else hostName;
  domain = defaultDomain config.networking.hostName;

  userOpts = {
    name,
    config,
    ...
  }: {
    options = {
      enable = mkEnableOption "the user";

      name = mkOption {
        description = "Username of the user";
        type = types.str;
      };

      fullName = mkOption {
        description = "Full name of the user";
        type = types.str;
      };

      admin = mkOption {
        description = "Is the user an admin";
        default = false;
        type = types.bool;
      };

      email = mkOption {
        description = "Email of the user";
        default = "${name}@${domain}";
        type = types.strMatching ".*@.*";
      };

      gitEmail = mkOption {
        description = "Email of the user to use for git commits";
        type = types.strMatching ".*@.*";
      };

      public_keys = mkOption {
        type = with types; listOf ext_lib.pub_key_type;
        description = "Public keys of the user, without the user@host part";
        default = [];
      };

      passwordSecretFile = mkOption {
        type = types.nullOr types.path;
        description = "Path to a age file containing the password of the user";
        default = null;
      };
    };
    config = {
      name = mkDefault name;
    };
  };
in {
  options.settings = {
    users = {
      users = mkOption {
        type = with types; attrsOf (submodule userOpts);
        description = "Set of users to create and configure";
        default = {};
      };
    };
  };

  config = let
    public_keys_for = user:
      map (key: "${key} ${user.name}")
      user.public_keys;
    mkSecret = _: user:
      nameValuePair "password-${user.name}" {
        file = user.passwordSecretFile;
        path = "/run/agenix/password/${user.name}";
        group = "admin";
        mode = "740";
      };
    mkSecrets = ext_lib.compose [
      (mapAttrs' mkSecret)
      (filterAttrs (_: conf: conf.enable && conf.passwordSecretFile != null))
    ];
  in {
    # TODO Create a "just" script to update a user password e.g. whoami + mkpasswd -m sha-512 + update the file
    age.secrets = mkSecrets cfg.users;
    users = {
      defaultUserShell = pkgs.zsh;

      groups =
        # Create a group per user
        ext_lib.compose [
          (mapAttrs' (_: u: nameValuePair u.name {}))
          ext_lib.filterEnabled
        ]
        cfg.users;

      users = let
        mkUser = _: user:
          {
            name = user.name;
            shell = config.users.defaultUserShell;
            openssh.authorizedKeys.keys = public_keys_for user;
            createHome = true;
            # ? equivalent to home-manager.users.${username}.home.homeDirectory?
          }
          // optionalAttrs isLinux {
            extraGroups =
              (
                if user.admin
                then ["wheel"]
                else []
              )
              ++ ["users"];
            home = "/home/${user.name}";
            passwordFile = config.age.secrets."password-${user.name}".path;
            isNormalUser = true;
          }
          // optionalAttrs isDarwin {
            # TODO make it work with Darwin. nix-darwin doesn't support users.users.<name>.groups or .extraGroups
            # extraGroups = mkIf user.admin [ "@admin" ];
            home = "/Users/${user.name}";
          };

        mkUsers = ext_lib.compose [
          (mapAttrs mkUser)
          ext_lib.filterEnabled
        ];
      in
        mkUsers cfg.users;
    };
  };
}
