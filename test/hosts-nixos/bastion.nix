{hardware, ...}: {
  imports = [hardware.aarch64];
  settings = {
    sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfpP5+ngbZu26pN1SKGeXWDzp4BXS0HVIH3C9bp5CQp";
    networking = {
      publicIP = "1.2.3.4";
      vpn = {
        id = 1;
        publicKey = "Juozjo5Mi2zPm0fwhHlo3b5956HtZOw0MxdYWOjA2XU=";
        bastion = {
          enable = true;
          port = 51820;
        };
      };
    };
  };
}
