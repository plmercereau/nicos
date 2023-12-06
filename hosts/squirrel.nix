{
  homebrew.casks = [
    "google-chrome" # nix package only for linux
    "skype"
    "sonos"
    "webex"
  ];

  settings.users.users.madhu.enable = lib.mkForce true;
  home-manager.users.madhu = import ../home-manager/madhu.nix;
}
