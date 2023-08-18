let
  pilou = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGd6o/NuO04nLqahrci03Itd/1yoK76ZpzKGgpwAEctb pilou@MBP-Pilou";
  users = [ pilou ];

  mbp = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKcwa/PgM3iOEzPdIfLwtpssHtozAzhU4I0g4Iked/LE";
  systems = [ mbp ];
in
{
  "wifi-install.age".publicKeys = [ pilou mbp ];
}
