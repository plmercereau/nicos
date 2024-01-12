pkgs:
pkgs.writeShellApplication {
  name = "doc";
  runtimeInputs = [pkgs.nodejs];
  text = ''
    cd docs
    npx mintlify dev
  '';
}
