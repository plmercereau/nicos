{
  lib,
  pkgs,
  ...
}: {
  imports = [./raspberry-pi.nix];

  # * See (closed): https://github.com/NixOS/nixpkgs/issues/126755#issuecomment-869149243
  # * See (opened): https://github.com/NixOS/nixpkgs/issues/154163
  nixpkgs.overlays = [
    (final: super: {
      makeModulesClosure = x:
        super.makeModulesClosure (x // {allowMissing = true;});
    })
  ];

  hardware.enableRedistributableFirmware = true;
  boot.kernelPackages = pkgs.linuxKernel.packages.linux_rpi4;

  nix.settings.cores = lib.mkDefault 4;
}
