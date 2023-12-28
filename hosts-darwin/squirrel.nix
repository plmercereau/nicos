{hardware, ...}: {
  imports = [hardware.m1];

  settings = {
    id = 5;
    sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKcwa/PgM3iOEzPdIfLwtpssHtozAzhU4I0g4Iked/LE";
    networking = {
      localIP = "10.136.1.133";
      vpn = {
        enable = true;
        publicKey = "4Y/frov/D/Y2Fpf5QpHXQU1zKltS63rChNSPGPlDV2w=";
      };
    };
  };

  homebrew.casks = [
    "google-chrome" # nix package only for linux
    "skype"
    "sonos"
    "webex"
  ];

  settings.users.users.madhu.enable = true;
  home-manager.users.madhu = import ../home-manager/madhu.nix;
}
