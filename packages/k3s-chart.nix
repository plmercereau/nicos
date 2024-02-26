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
          chartContent = "ref+envsubst://$CHART";
        }
      )
      // optionalAttrs (values != null) {
        valuesContent = "ref+envsubst://$VALUES";
      };
  });
in
  pkgs.writeScript "k3s-chart" ''
    set -euo pipefail
    mkdir -p ${manifestsPath}
    ${optionalString (src != null) ''
      export CHART=$(${pkgs.coreutils}/bin/base64 ${pkgs.helm-package name src}/${name}.tgz)
    ''}
    ${optionalString (values != null) ''
      export VALUES="$(cat ${pkgs.writeScript "values" (strings.toJSON values)})"
    ''}
    echo "Installing ${name} chart into ${manifestsPath}/${name}.yaml"
    rm -f ${manifestsPath}/${name}.yaml
    ${pkgs.vals}/bin/vals eval -f ${template} > ${manifestsPath}/${name}.yaml
  ''
