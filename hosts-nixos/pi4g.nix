{
  config,
  hardware,
  ...
}: {
  imports = [hardware.raspberrypi-4];
  nixpkgs.hostPlatform = "aarch64-linux";
  settings = {
    id = 4;
    localIP = "10.136.1.77";
    sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOJHOROkjkRpE/tlzhekhd4O2sMJKnBNycC/T87h+63D";
    wireguard.publicKey = "16u3+D45pngM5UPMNxoxZkfd+CYAwLjfqGIadMMkAwQ=";

    profile = "minimal";
    impermanence.enable = true;
  };
}
