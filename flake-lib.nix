inputs @ {
  nixpkgs,
  agenix,
  disko,
  impermanence,
  home-manager,
  srvos,
  ...
}:
with nixpkgs.lib; rec {
  features = import ./features inputs;

  hardware = import ./hardware;

  specialArgs = {
    hardware = hardware.modules;
    srvos = srvos.nixosModules;
  };

  overlays = rec {
    nicos = final: prev: {
      k3s-ca-certs = prev.callPackage ./packages/k3s-ca-certs.nix {};
      k3s-chart-config = prev.callPackage ./packages/k3s-chart-config.nix {};
      k3s-chart = prev.callPackage ./packages/k3s-chart.nix {};
      k8s-apply-secret = prev.callPackage ./packages/k8s-apply-secret.nix {};
      helm-package = prev.callPackage ./packages/helm-package.nix {};
    };
    default = nicos;
  };

  nixosModules = rec {
    nicos =
      [
        agenix.nixosModules.default
        disko.nixosModules.disko
        impermanence.nixosModules.impermanence
        home-manager.nixosModules.home-manager
        {nixpkgs.overlays = [overlays.default];}
        ./modules
      ]
      ++ (features.modules);
    default = nicos;
  };

  printMachine = name: traceIf (builtins.getEnv "VERBOSE" == "1") "Evaluating machine: ${name}";

  hostsList = root: path:
    if (path == null)
    then []
    else
      foldlAttrs (acc: name: type: acc ++ optional (type == "regular" && hasSuffix ".nix" name) (removeSuffix ".nix" name))
      []
      (builtins.readDir (root + "/${path}"));
}
