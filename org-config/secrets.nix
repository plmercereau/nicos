let
  pkgs = import <nixpkgs> {};
  lib = pkgs.lib;
  inherit (import ../lib.nix {inherit lib;}) mkUsersSecrets mkAdminsKeysList mkHostsKeysList;

  usersSecrets = mkUsersSecrets ./. {inherit pkgs lib;};
  adminsKeys = mkAdminsKeysList ./users {inherit pkgs lib;};
  hostsKeys = mkHostsKeysList ./hosts;
in
  {
    "./bootstrap/wifi.age".publicKeys = adminsKeys;
    "./wifi/psk.age".publicKeys = hostsKeys ++ adminsKeys;
  }
  // usersSecrets
