{pkgs}:
pkgs.writeShellApplication {
  name = "nicos-doc";
  runtimeInputs = [pkgs.nodejs];
  text = ''
    cd docs
    npx mintlify dev
  '';
}
