# Settings common to all the machines
{
  time.timeZone = "Europe/Brussels";
  settings.localNetworkId = "mjmp";
  home-manager.users.pilou = import ./home-manager/pilou.nix;
}
