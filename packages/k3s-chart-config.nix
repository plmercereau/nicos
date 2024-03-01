{
  pkgs,
  lib,
}: name:
with lib; let
  manifestsPath = "/var/lib/rancher/k3s/server/manifests";
  template = pkgs.writeText "chart-config.yaml" (
    strings.toJSON {
      apiVersion = "helm.cattle.io/v1";
      kind = "HelmChartConfig";
      metadata = {
        inherit name;
        namespace = "kube-system";
      };
      spec.valuesContent = "ref+envsubst://$VALUES";
    }
  );
in
  pkgs.writeScript "k3s-chart-config" ''
    set -e
    mkdir -p ${manifestsPath}
    export VALUES="$1"
    echo "Installing chart config ${name} into ${manifestsPath}/${name}-config.yaml"
    rm -f ${manifestsPath}/${name}-config.yaml
    ${pkgs.vals}/bin/vals eval -f ${template} > ${manifestsPath}/${name}-config.yaml
  ''
