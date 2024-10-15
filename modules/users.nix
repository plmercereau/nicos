{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  inherit (config.lib) ext_lib;
  cfg = config.settings.users;

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
    # Wheel group doesn't need a password so they can deploy using deploy-rs
    security.sudo.wheelNeedsPassword = false;

    users = {
      # Users can't change their own shell/password, it should happen in the Nix config
      mutableUsers = false;
      defaultUserShell = pkgs.zsh;

      groups =
        # Create a group per user
        ext_lib.compose [
          (mapAttrs (name: user: {}))
          ext_lib.filterEnabled
        ]
        cfg.users;

      users = let
        mkUser = name: user: {
          inherit name;
          shell = config.users.defaultUserShell;
          openssh.authorizedKeys.keys = publicKeysFor name user;
          createHome = true;
          # ? equivalent to home-manager.users.${username}.home.homeDirectory?
          isNormalUser = !user.isSystemUser;
          extraGroups = ["users"] ++ lib.optional (user.isAdmin) "wheel";
          home = "/home/${name}";
          # TODO move reference to age to the "users" feature so the module works without using the "configure" function
          hashedPasswordFile = let
            path = lib.attrByPath ["password_${name}" "path"] null config.age.secrets;
          in
            lib.mkIf (path != null) path;
        };
      in
        {
          # Deactivate password login for root
          root.hashedPassword = "!";
        }
        // (ext_lib.compose [
          (mapAttrs mkUser)
          ext_lib.filterEnabled
        ])
        cfg.users;
    };
  };
}
