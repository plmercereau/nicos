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
      enable = mkEnableOption "the user is enabled or not";

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

      public_keys = mkOption {
        type = with types; listOf ext_lib.pub_key_type;
        description = "Public keys of the user, without the user@host part";
        default = [];
      };
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
    public_keys_for = name: user:
      map (key: "${key} ${name}")
      user.public_keys;
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
            openssh.authorizedKeys.keys = public_keys_for name user;
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
            home = "/home/${name}";
            hashedPasswordFile = config.age.secrets."password_${name}".path;
            isNormalUser = true;
          }
          // optionalAttrs isDarwin {
            # TODO make it work with Darwin. nix-darwin doesn't support users.users.<name>.groups or .extraGroups
            # * See https://daiderd.com/nix-darwin/manual/index.html#opt-users.groups
            # extraGroups = mkIf user.admin [ "@admin" ];
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
