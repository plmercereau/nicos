{
  pkgs,
  lib,
}: {
  name,
  namespace,
  src ? null,
  repo ? null,
  chart ? null,
  version ? null,
  values ? null,
  set ? {},
}:
with lib; let
  manifestsPath = "/var/lib/rancher/k3s/server/manifests";
  template = pkgs.writeText "chart.yaml" (strings.toJSON {
    apiVersion = "helm.cattle.io/v1";
    kind = "HelmChart";
    metadata = {
      inherit name;
      namespace = "kube-system";
    };
    spec =
      {
        targetNamespace = namespace;
        createNamespace = true;
        inherit set;
      }
      // (
        if (src == null)
        then {inherit chart;} // (optionalAttrs (repo != null) {inherit repo version;})
        else {
          chartContent = let
            file = pkgs.runCommand "chart" {} ''
              cat ${pkgs.helm-package name src}/${name}.tgz | ${pkgs.coreutils}/bin/base64 -w 0 > $out
            '';
          in "ref+file://${file}";
        }
      )
      // optionalAttrs (values != null) {
        valuesContent = strings.toJSON values;
      };
  });
in
  pkgs.writeScript "k3s-chart" ''
    set -e
    mkdir -p ${manifestsPath}
    echo "Installing chart ${name} into ${manifestsPath}/${name}.yaml"
    rm -f ${manifestsPath}/${name}.yaml
    ${pkgs.vals}/bin/vals eval -f ${template} > ${manifestsPath}/${name}.yaml
  ''
