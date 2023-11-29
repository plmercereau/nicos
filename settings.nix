# Settings common to all the machines
{
  nixpkgs.config.allowUnfree = true;
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
  };

  time.timeZone = "Europe/Brussels";
  settings.localNetworkId = "mjmp";
  home-manager.users.pilou = import ./home-manager/pilou.nix;
}
