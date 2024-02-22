{pkgs}: name: src:
pkgs.runCommand name {} ''
  mkdir -p $out
  ${pkgs.kubernetes-helm}/bin/helm package ${src}
  cp *.tgz $out/${name}.tgz
''
