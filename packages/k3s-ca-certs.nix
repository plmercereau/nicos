# TODO unused
pkgs: let
  inherit (pkgs) lib;
in
  pkgs.stdenv.mkDerivation rec {
    name = "k3s-ca-certs";

    src = pkgs.fetchFromGitHub {
      owner = "k3s-io";
      repo = "k3s";
      rev = "6d77b7a9204ebe40c53425ce4bc82c1df456e911";
      hash = "sha256-1bCedpfkSckqvZn2HUPY2URNF/WcW8Pz1C9QtMSCKnU=";
    };

    buildPhase = ''
      # Your build commands here!
    '';

    propagatedBuildInputs = [pkgs.openssl];

    installPhase = ''
      mkdir -p $out/bin
      cp -r contrib/util/generate-custom-ca-certs.sh $out/bin/${name}
      chmod +x $out/bin/${name}
    '';

    meta = {
      description = "pre-create the appropriate certificates and keys for a k3s cluster";
    };
  }
