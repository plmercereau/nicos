inputs @ {
  agenix,
  deploy-rs,
  disko,
  home-manager,
  impermanence,
  nix-darwin,
  nixpkgs,
  srvos,
  ...
}: {
  hosts,
  adminKeys,
  nixos,
  darwin,
  builders,
  users,
  wifi,
  ...
}: let
  inherit (nixpkgs) lib;
  wifi = import ./wifi.nix inputs;
  builders = import ./builders.nix inputs;
  vpn = import ./vpn.nix inputs;
  users = import ./users.nix inputs;

  vpnSecrets = vpn.secrets {inherit adminKeys nixos darwin hosts;};
  usersSecrets = users.secrets {inherit users adminKeys hosts;};
  wifiSecret = wifi.secrets {inherit wifi adminKeys hosts;};
  nixBuilderSecret = builders.secrets {inherit builders adminKeys;};
in
  vpnSecrets // usersSecrets // wifiSecret // nixBuilderSecret
