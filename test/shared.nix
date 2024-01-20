# Settings common to all the machines
{
  cluster,
  pkgs,
  ...
}: {
  settings = {
    networking.vpn.enable = true;
    users.users = {
      pilou = {
        enable = true;
        isAdmin = true;
        publicKeys = cluster.adminKeys;
      };
    };
  };
}
