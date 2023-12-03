{
  homebrew.casks = [
    "google-chrome" # nix package only for linux
    "skype"
    "sonos"
    "webex"
  ];

  environment.systemPackages = with pkgs; [
    iina # TODO home-manager Madhu: iina, spotify, sonos
  ];
}
