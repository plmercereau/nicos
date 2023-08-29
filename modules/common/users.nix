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
  in {
    users =
      {
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
              extraGroups = mkIf user.admin ["wheel"];
              home = "/home/${user.name}";
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
      }
      // optionalAttrs isLinux {
        # Not available in Darwin. Users can't change their own shell/password, it happens in the Nix config
        mutableUsers = false;
      };
  };
}
