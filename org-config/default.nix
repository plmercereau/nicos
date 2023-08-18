{ config, lib, ... }:
{
  imports = [
    ./environment.nix
    ./users.nix
  ];
}
