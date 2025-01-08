{
  agenix,
  deploy-rs,
  disko,
  home-manager,
  impermanence,
  nixpkgs,
  ...
}:
with nixpkgs.lib; let
  # Get only the "<key-type> <key-value>" part of a public key (trim the potential comment e.g. user@host)
  trimPublicKey = key: let
    split = splitString " " key;
  in "${builtins.elemAt split 0} ${builtins.elemAt split 1}";
in {
  module = {
    config,
    cluster,
    ...
  }: let
    inherit (cluster) projectRoot users;
  in {
    # Load user passwords
    age.secrets = optionalAttrs users.enable (
      foldlAttrs
      (
        acc: name: config: let
          path = projectRoot + "/${users.path}/${name}.hash.age";
        in
          acc // optionalAttrs (builtins.pathExists path) {"password_${name}".file = path;}
      )
      {}
      config.users.users
    );
  };

  /*
  Accessible by:
  (1) users with config.users.users.<user>.openssh.authorizedKeys.keys in at least one of the hosts
  (2) hosts where the user exists (config.users.users exists)
  (3) cluster admins
  */
  secrets = {
    users,
    adminKeys,
    hosts,
    ...
  }:
    optionalAttrs users.enable
    (foldlAttrs (
        hostAcc: _: host:
          foldlAttrs (
            userAcc: userName: user: let
              userKeys = attrByPath ["openssh" "authorizedKeys" "keys"] [] user;
              keyName = "${users.path}/${userName}.hash.age";
              currentKeys = attrByPath [keyName "publicKeys"] [] userAcc;
            in
              userAcc
              // {
                "${keyName}".publicKeys = unique (
                  builtins.map trimPublicKey
                  (
                    currentKeys
                    ++ adminKeys # (3)
                    ++ [host.settings.sshPublicKey] # (2)
                    ++ (optionals ((builtins.length userKeys) > 0) userKeys) # (1)
                  )
                );
              }
          )
          hostAcc
          host.users.users
      )
      {}
      hosts);
}
