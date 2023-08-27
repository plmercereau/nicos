{ pkgs, ... }: {
  users.defaultUserShell = pkgs.zsh;
  settings.users.users = {
    pilou = {
      enable = true;
      admin = true;
      name = "pilou";
      fullName = "Pierre-Louis Mercereau";
      gitEmail = "24897252+plmercereau@users.noreply.github.com";
      public_keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCyxrQiE8bx1R9SG4fuNebXP8oq1duReM7E7W2M0i0fsC3PrKwQ6c9R4qzNQLREeWwtCWV0KEl0K+iriiIPa7D5psEASJapGyi5NtqEqZbM+a8BGQNdy82zEU4xU6IA4GyjxqPb/0zRiEh//4RuePZGNItW2Gl+1ZvOA1UTsHZKpGgZxWewoGdtm6EwscTy+5A4uanFWmxtpajy5J1GVR038quQLszSsTfTRr0gA80+uQbahHlGmP9HlyXrjaeKtSz9XTT95XmC/rVJkIKBYEIEf2fyV+O3hB1cxh+fb/lHFqoIJrES1qU4TAzs58Ioj0Jd3xlPGa96VJewrNXKbFjP"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGd6o/NuO04nLqahrci03Itd/1yoK76ZpzKGgpwAEctb"
      ];
    };

  };
}
