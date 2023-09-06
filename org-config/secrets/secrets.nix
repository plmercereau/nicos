with builtins; let
  pkgs = import <nixpkgs> {};
  lib = pkgs.lib;
  usersConfig = import ../users.nix {inherit pkgs;};

  users = mapAttrs (name: value: value.public_keys) usersConfig.settings.users.users;
  usersKeys = concatLists (attrValues users);

  # TODO infer from users config
  admins = users.pilou;

  loadHostsKeys = hostsPath:
    lib.mapAttrs'
    (name: value:
      lib.nameValuePair (lib.removeSuffix ".key" name)
      (lib.remove "" (lib.splitString "\n" (readFile "${toPath hostsPath}/${name}"))))
    (lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".key" name)
      (readDir (toPath hostsPath)));

  hosts = (loadHostsKeys ../hosts/darwin) // (loadHostsKeys ../hosts/linux);
  hostsKeys = concatLists (attrValues hosts);
in {
  "wifi-install.age".publicKeys = admins;
  "wifi.age".publicKeys = hostsKeys ++ admins;
}
