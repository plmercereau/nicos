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
      enable = mkOption {
        description = "Whether the user is enabled in the machine.";
        default = false;
        type = types.bool;
      };

      isAdmin = mkOption {
        description = "Whether the user is an admin of the machine.";
        default = false;
        type = types.bool;
      };

      isSystemUser = mkOption {
        description = "Whether the user is a system user.";
        default = false;
        type = types.bool;
      };

      publicKeys = mkOption {
        type = with types; listOf ext_lib.pub_key_type;
        description = "Public keys of the user, without the comment (user@host) part.";
        default = [];
      };
    };
  };
in {
  options.settings = {
    users = {
      users = mkOption {
        type = with types; attrsOf (submodule userOpts);
        description = "Set of users to create and configure.";
        default = {};
      };
    };
  };

  config = let
    publicKeysFor = name: user:
      map (key: "${key} ${name}")
      user.publicKeys;
  in {
    users = {
      defaultUserShell = pkgs.zsh;

      groups =
        # Create a group per user
        ext_lib.compose [
          (mapAttrs (name: user: {}))
          ext_lib.filterEnabled
        ]
        cfg.users;

      users = let
        mkUser = name: user:
          {
            inherit name;
            shell = config.users.defaultUserShell;
            openssh.authorizedKeys.keys = publicKeysFor name user;
            createHome = true;
            # ? equivalent to home-manager.users.${username}.home.homeDirectory?
          }
          // optionalAttrs isLinux {
            isNormalUser = !user.isSystemUser;
            extraGroups = ["users"] ++ lib.optional (user.isAdmin) "wheel";
            home = "/home/${name}";
            # TODO move reference to age to the "users" feature so the module works without using the "configure" function
            hashedPasswordFile = let
              path = lib.attrByPath ["password_${name}" "path"] null config.age.secrets;
            in
              lib.mkIf (path != null) path;
          }
          // optionalAttrs isDarwin {
            # TODO make it work with Darwin. nix-darwin doesn't support users.users.<name>.groups or .extraGroups
            # * See https://daiderd.com/nix-darwin/manual/index.html#opt-users.groups
            # extraGroups = mkIf user.isAdmin [ "@admin" ];
            home = "/Users/${name}";
          };
      in
        (ext_lib.compose [
          (mapAttrs mkUser)
          ext_lib.filterEnabled
        ])
        cfg.users;
    };
  };
}
