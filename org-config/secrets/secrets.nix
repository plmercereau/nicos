# TODO put most of the logic of this file into lib.nix
with builtins; let
  pkgs = import <nixpkgs> {};
  lib = pkgs.lib;
  myLib = import ../../lib.nix {inherit lib;};

  userSettings = myLib.mkUsersSettings ../users {inherit pkgs lib;};
  users = userSettings.settings.users.users;

  # Admins are all users defined in ../users/*.nix with admin = true
  admins = lib.filterAttrs (name: value: hasAttr "admin" value && value.admin == true) users;
  adminsKeys = concatLists (attrValues (mapAttrs (name: value: value.public_keys) admins));

  loadHostsKeys = hostsPath:
    lib.mapAttrs'
    (name: value:
      lib.nameValuePair (lib.removeSuffix ".key" name)
      (lib.remove "" (lib.splitString "\n" (readFile "${toPath hostsPath}/${name}"))))
    (lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".key" name)
      (readDir (toPath hostsPath)));

  hosts = (loadHostsKeys ../hosts/darwin) // (loadHostsKeys ../hosts/linux);
  hostsKeys = concatLists (attrValues hosts);
in
  {
    # TODO move org-config/secrets/secrets.nix to org-config/secrets.nix
    # TODO move to ../bootstrap/wifi.nix
    "wifi-install.age".publicKeys = adminsKeys;
    "../wifi/psk.age".publicKeys = hostsKeys ++ adminsKeys;
  }
  # * add per-user ../users/*.hash.age
  // lib.mapAttrs'
  (name: value: lib.nameValuePair "../users/${name}.hash.age" {publicKeys = value.public_keys ++ adminsKeys;})
  users
