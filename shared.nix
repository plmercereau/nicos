# Settings common to all the machines
{cluster, ...}: {
  nixpkgs.config.allowUnfree = true;
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
  };

  time.timeZone = "Europe/Brussels";
  settings = {
    networking.localNetworkId = "mjmp";
    users.users = {
      pilou = {
        enable = true;
        admin = true;
        publicKeys = cluster.adminKeys;
      };
    };
  };
  home-manager.users.pilou = import ./home-manager/pilou-minimal.nix;
}
