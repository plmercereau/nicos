let
  pkgs = import <nixpkgs> {};
  lib = pkgs.lib;
  inherit (import ./lib.nix {inherit lib;}) mkUsersSecrets mkAdminsKeysList mkHostsKeysList mkWireGuardSecrets;
  wireGuardSecrets = mkWireGuardSecrets ./. {inherit pkgs lib;};
  usersSecrets = mkUsersSecrets ./. {inherit pkgs lib;};
  adminsKeys = mkAdminsKeysList ./users;
  hostsKeys = mkHostsKeysList ./hosts;
in
  {
    "./wifi/psk.age".publicKeys = hostsKeys ++ adminsKeys;
  }
  // usersSecrets
  // wireGuardSecrets
