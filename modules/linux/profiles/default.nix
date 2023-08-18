{ modulesPath, ... }:
{
  imports = [
    ./options.nix
    ./minimal.nix
  ];
  disabledModules = [
    (modulesPath + "/profiles/all-hardware.nix")
    (modulesPath + "/profiles/base.nix")
  ];

}
