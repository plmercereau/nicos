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
      }
      // (
        if (src == null)
        then {inherit repo chart version;}
        else {
          chartContent = "ref+envsubst://$CHART";
        }
      );
  });
in
  pkgs.writeScript "k3s-chart" ''
    set -euo pipefail
    mkdir -p ${manifestsPath}
    ${optionalString (src != null) ''
      export CHART=$(${pkgs.coreutils}/bin/base64 ${pkgs.helm-package name src}/${name}.tgz)
    ''}
    rm -f ${manifestsPath}/${name}.yaml
    ${pkgs.vals}/bin/vals eval -f ${template} > ${manifestsPath}/${name}.yaml
  ''
