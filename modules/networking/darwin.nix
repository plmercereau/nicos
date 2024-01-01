{
  lib,
  pkgs,
  config,
  ...
}:
with lib; let
  cfg = config.networking;
in {
  # ! Interoperability with the Nixos "hosts" options.
  # See: https://github.com/NixOS/nixpkgs/blob/nixos-23.11/nixos/modules/config/networking.nix
  options = {
    networking.hosts = mkOption {
      type = types.attrsOf (types.listOf types.str);
      example = literalExpression ''
        {
          "127.0.0.1" = [ "foo.bar.baz" ];
          "192.168.0.2" = [ "fileserver.local" "nameserver.local" ];
        };
      '';
      description = mdDoc ''
        Locally defined maps of hostnames to IP addresses.
      '';
      default = {}; # ! deploy-rs fails if not default is set.
    };
    networking.hostFiles = lib.mkOption {
      type = types.listOf types.path;
      defaultText = literalMD "Hosts from {option}`networking.hosts` and {option}`networking.extraHosts`";
      example = literalExpression ''[ "''${pkgs.my-blocklist-package}/share/my-blocklist/hosts" ]'';
      description = lib.mdDoc ''
        Files that should be concatenated together to form {file}`/etc/hosts`.
      '';
    };
    networking.extraHosts = mkOption {
      type = types.lines;
      default = "";
      example = "192.168.0.1 lanlocalhost";
      description = mdDoc ''
        Additional verbatim entries to be appended to {file}`/etc/hosts`.
        For adding hosts from derivation results, use {option}`networking.hostFiles` instead.
      '';
    };
  };

  config = {
    networking.hostFiles = let
      # ! Set the defauls present in Darwin machines
      localhostHosts = pkgs.writeText "localhost-hosts" ''
        127.0.0.1       localhost localhost.localdomain localhost4 localhost4.localdomain4
        ::1             localhost
        255.255.255.255 broadcasthost
      '';
      stringHosts = let
        oneToString = set: ip: ip + " " + concatStringsSep " " set.${ip} + "\n";
        allToString = set: concatMapStrings (oneToString set) (attrNames set);
      in
        pkgs.writeText "string-hosts" (allToString (filterAttrs (_: v: v != []) cfg.hosts));
      extraHosts = pkgs.writeText "extra-hosts" cfg.extraHosts;
    in
      mkBefore [localhostHosts stringHosts extraHosts];

    environment.etc.hosts.source = pkgs.concatText "hosts" cfg.hostFiles;
  };
}
