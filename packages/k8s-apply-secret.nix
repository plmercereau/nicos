{
  pkgs,
  lib,
}: {
  name,
  namespace,
  values,
  wait ? false,
}:
with lib; let
  secret = pkgs.writeText "kube-vip-secret.json" (strings.toJSON {
    apiVersion = "v1";
    kind = "Secret";
    metadata = {
      inherit name namespace;
    };
    type = "Opaque";
    data = mapAttrs (name: _: "ref+envsubst://\$${name}") values;
  });
in
  pkgs.writeShellScript "set-secret-${namespace}-${name}" ''
    ${
      optionalString wait ''
        while true; do
            if "$(${pkgs.kubectl}/bin/kubectl config view -o json --raw)" | ${pkgs.jq}/bin/jq '.clusters | length' | grep -q '^0$'; then
                echo "Error: No clusters found in kubeconfig. Assuming the cluster is not ready yet. Retrying in 1 second..."
                sleep 1
            else
                break
            fi
        done
      ''
    }
    ${concatStringsSep "\n" (mapAttrsToList (name: value: ''
        export ${name}=$(${
          if isString value
          then "echo -n \"${value}\""
          else "cat \"${value.file}\""
        } | base64)
      '')
      values)}
    ${pkgs.vals}/bin/vals eval -f ${secret} | ${pkgs.kubectl}/bin/kubectl apply -f -
  ''
