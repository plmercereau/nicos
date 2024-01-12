# Settings common to all the machines
{
  cluster,
  pkgs,
  ...
}: {
  settings = {
    users.users = {
      # The {{ user }} user is enabled and the administrator of every machine
      {{ user }} = {
        enable = true;
        isAdmin = true;
        publicKeys = cluster.adminKeys;
      };
    };
  };
}
