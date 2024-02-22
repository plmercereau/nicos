{
  pkgs,
  lib,
}: name: src:
pkgs.runCommand name {} ''
  mkdir -p $out
  set -euo pipefail
  ${pkgs.kubernetes-helm}/bin/helm package ${src}
  cp *.tgz $out/${name}.tgz
''
