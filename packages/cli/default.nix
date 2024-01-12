pkgs: {
  agenix,
  nixos-anywhere,
  nixpkgs,
  ...
}: let
  inherit (nixpkgs) lib;
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
      # not very elegant
      ++ (lib.optional (pkgs.hostPlatform.isLinux) (import ../mount-image.nix pkgs))
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
