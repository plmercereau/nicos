{
  lib,
  pkgs,
  config,
  ...
}:
with lib; let
  filterEnabled = lib.filterAttrs (_: conf: conf.enable);

  # compose [ f g h ] x == f (g (h x))
  compose = let
    apply = f: x: f x;
  in
    lib.flip (lib.foldr apply);

  adminKeys =
    lib.foldlAttrs
    (acc: _: user: acc ++ lib.optionals (user.isAdmin) user.publicKeys)
    []
    config.settings.users.users;

  pub_key_type = let
    key_data_pattern = "[[:lower:][:upper:][:digit:]\\/+]";
    key_patterns = let
      /*
          These prefixes consist out of 3 null bytes followed by a byte giving
      the length of the name of the key type, followed by the key type itself,
      and all of this encoded as base64.
      So "ssh-ed25519" is 11 characters long, which is \x0b, and thus we get
        b64_encode(b"\x00\x00\x00\x0bssh-ed25519")
      For "ecdsa-sha2-nistp256", we have 19 chars, or \x13, and we get
        b64encode(b"\x00\x00\x00\x13ecdsa-sha2-nistp256")
      For "ssh-rsa", we have 7 chars, or \x07, and we get
        b64encode(b"\x00\x00\x00\x07ssh-rsa")
      */
      ed25519_prefix = "AAAAC3NzaC1lZDI1NTE5";
      nistp256_prefix = "AAAAE2VjZHNhLXNoYTItbmlzdHAyNTY";
      rsa_prefix = "AAAAB3NzaC1yc2E";
    in {
      ssh-ed25519 = "^ssh-ed25519 ${ed25519_prefix}${key_data_pattern}{48}$";
      ecdsa-sha2-nistp256 = "^ecdsa-sha2-nistp256 ${nistp256_prefix}${key_data_pattern}{108}=$";
      # We require 2048 bits minimum. This limit might need to be increased
      # at some point since 2048 bit RSA is not considered very secure anymore
      ssh-rsa = "^ssh-rsa ${rsa_prefix}${key_data_pattern}{355,}={0,2}$";
    };
    pub_key_pattern = concatStringsSep "|" (attrValues key_patterns);
    description =
      ''valid ${concatStringsSep " or " (attrNames key_patterns)} key, ''
      + ''meaning a string matching the pattern ${pub_key_pattern}'';
  in
    types.strMatching pub_key_pattern // {inherit description;};

  idToVpnIp = id: "${config.settings.networking.vpn.ipPrefix}.${builtins.toString id}";
in {
  config.lib.ext_lib = {
    inherit
      compose
      filterEnabled
      pub_key_type
      adminKeys
      idToVpnIp
      ;
  };
}
