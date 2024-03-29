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
  contentValues = filterAttrs (_: value: value ? "content") values;
  fileValues = filterAttrs (_: value: value ? "file") values;
  secret = pkgs.writeText "secret.json" (strings.toJSON {
    apiVersion = "v1";
    kind = "Secret";
    metadata = {
      inherit name namespace;
    };
    type = "Opaque";
    data =
      (mapAttrs (name: _: "ref+envsubst://\$${name}") contentValues)
      // (
        mapAttrs (_: value: "ref+file://${value.file}?encode=base64") fileValues
      );
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
    ${concatStringsSep "\n" (mapAttrsToList (
        name: value: let
          inherit (value) content;
          file = pkgs.writeText name (
            if isString content
            then content
            else strings.toJSON content
          );
        in ''
          export ${name}=$(cat ${file} | base64)
        ''
      )
      contentValues)}
    ${pkgs.vals}/bin/vals eval -f ${secret} | ${pkgs.kubectl}/bin/kubectl apply -f -
  ''
