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

  package = pkgs.runCommand "package.tgz" {} ''
    set -euo pipefail
    ${pkgs.kubernetes-helm}/bin/helm package ${src}
    ${pkgs.coreutils}/bin/cat *.tgz > $out
  '';
in
  pkgs.writeScript "k3s-chart" ''
    set -euo pipefail
    mkdir -p ${manifestsPath}
    ${optionalString (src != null) ''
      export CHART=$(${pkgs.coreutils}/bin/base64 ${package})
    ''}
    rm -f ${manifestsPath}/${name}.yaml
    ${pkgs.vals}/bin/vals eval -f ${template} > ${manifestsPath}/${name}.yaml
  ''
