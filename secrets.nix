let
  pkgs = import <nixpkgs> {};
  lib = pkgs.lib;
  inherit (import ./lib.nix {inherit lib;}) mkUsersSecrets mkAdminsKeysList mkHostsKeysList;

  usersSecrets = mkUsersSecrets ./. {inherit pkgs lib;};
  adminsKeys = mkAdminsKeysList ./users;
  hostsKeys = mkHostsKeysList ./hosts;
in
  {
    "./wifi/psk.age".publicKeys = hostsKeys ++ adminsKeys;
    "./tunnel.age".publicKeys = hostsKeys ++ adminsKeys;
  }
  // usersSecrets
