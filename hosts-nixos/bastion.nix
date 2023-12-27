{hardware, ...}: {
  imports = [hardware.hetzner-x86];
  settings = {
    id = 1;
    sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfpP5+ngbZu26pN1SKGeXWDzp4BXS0HVIH3C9bp5CQp";
    networking = {
      publicIP = "128.140.39.64";
      vpn = {
        enable = true;
        publicKey = "Juozjo5Mi2zPm0fwhHlo3b5956HtZOw0MxdYWOjA2XU=";
        bastion = {
          enable = true;
          port = 51820;
        };
      };
    };
  };
}
