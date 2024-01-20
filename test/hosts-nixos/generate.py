import os
import shutil


for x in range(101, 1001):
    nix_file = f"./client-{x}.nix"
    age_file = f"./client-{x}.vpn.age"
    shutil.copyfile("./bastion.vpn.age", age_file)
    with open(nix_file, "w") as file:
        file.write(
            """
{config, hardware, ...}: {
  imports = [hardware.aarch64];
  settings = {
    sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfpP5+ngbZu26pN1SKGeXWDzp4BXS0HVIH3C9bp5CQp";
    networking = {
      vpn.publicKey = "16u3+D45pngM5UPMNxoxZkfd+CYAwLjfqGIadMMkAwQ=";
      vpn.id = %d;
    };
  };
}
            """
            % (x)
        )
