# Settings common to all the machines
{
  nixpkgs.config.allowUnfree = true;
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
  };

  time.timeZone = "Europe/Brussels";
  settings = {
    localNetworkId = "mjmp";
    users.users.pilou = {
      enable = true;
      admin = true;
    };
  };
  home-manager.users.pilou = import ./home-manager/pilou-minimal.nix;
}
