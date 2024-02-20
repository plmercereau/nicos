pkgs: name: let
  manifestsPath = "/var/lib/rancher/k3s/server/manifests";
  template = pkgs.writeText "chart.yaml" ''
    apiVersion: helm.cattle.io/v1
    kind: HelmChartConfig
    metadata:
      name: ${name}
      namespace: kube-system
    spec:
      valuesContent: ref+envsubst://$VALUES
  '';
in
  pkgs.writeScript "k3s-chart-config" ''
    set -euo pipefail
    mkdir -p ${manifestsPath}
    export VALUES="$1"
    ${pkgs.vals}/bin/vals eval -f ${template} > ${manifestsPath}/${name}-config.yaml
  ''
