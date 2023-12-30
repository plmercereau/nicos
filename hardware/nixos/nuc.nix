{
  lib,
  config,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix") # ?
    ./x86.nix
  ];

  nix.settings.cores = 12; # * depends on the NUC model, but 12 seems a reasonable default
  boot.kernelModules = ["kvm-intel"];

  # powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  hardware.bluetooth.enable = lib.mkDefault true; # enables support for Bluetooth
  hardware.bluetooth.powerOnBoot = lib.mkDefault true; # powers up the default Bluetooth controller on boot
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  networking.wireless.enable = lib.mkDefault true;
}
