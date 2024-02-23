{
  pkgs,
  lib,
}: {
  agenix,
  nixos-anywhere,
  ...
}: let
  python = pkgs.python3;
in
  python.pkgs.buildPythonApplication rec {
    name = "nicos";
    propagatedBuildInputs = (
      [
        agenix.packages.${pkgs.hostPlatform.system}.default
        nixos-anywhere.packages.${pkgs.hostPlatform.system}.default
        pkgs.rsync
        pkgs.wireguard-tools
      ]
      ++ (with python.pkgs; [
        bcrypt
        python-box
        click
        cryptography
        questionary
        jinja2
        psutil
      ])
    );
    src = ./.;
  }
