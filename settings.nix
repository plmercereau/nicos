# Settings common to all the machines
# TODO put the "pilou" user config here
{
  settings.localNetworkId = "mjmp";
  home-manager.users.pilou = import ./home-manager/profile-cli.nix;
}
