{
  config,
  hardware,
  ...
}: {
  imports = [hardware.raspberrypi-4];

  settings = {
    id = 4;
    sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOJHOROkjkRpE/tlzhekhd4O2sMJKnBNycC/T87h+63D";
    networking = {
      localIP = "10.136.1.77";
      vpn = {
        enable = true;
        publicKey = "16u3+D45pngM5UPMNxoxZkfd+CYAwLjfqGIadMMkAwQ=";
      };
    };
    impermanence.enable = true;
  };
}
