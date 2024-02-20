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
      k3s-ca-certs = import ./packages/k3s-ca-certs.nix prev;
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
