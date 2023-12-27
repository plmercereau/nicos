{hardware, ...}: {
  imports = [hardware.hetzner-x86];
  settings = {
    id = 7;
    sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO0e4xgSR+fNpnLPcB+EGzPYZ4wuCulH36OM0DQTAU5p";

    networking = {
      publicIP = "65.108.88.217";
      vpn = {
        enable = true;
        publicKey = "jW/AbaW8SSBKHUdYiSWQKuecN4Z1C04VcEnnin+A5y0=";
      };
    };
  };
}
