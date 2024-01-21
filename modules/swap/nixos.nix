# Poached from https://git.sr.ht/~r-vdp/resilientOS/tree/master/item/modules/swap.nix
{
  config,
  lib,
  ...
}: let
  cfg = config.settings.system.swap;
in
  with lib; {
    options.settings.system.swap = {
      zram = {
        enable = lib.mkOption {
          description = "Enable a swap file in a zram device.";
          type = lib.types.bool;
          default = true;
        };
      };
      file = {
        enable = lib.mkOption {
          description = "Enable a swap file on the root partition.";
          type = lib.types.bool;
          default = true;
        };

        size = lib.mkOption {
          type = lib.types.ints.between 0 10;
          default = 1;
          description = "Size of the swap file in GiB.";
        };
      };
    };

    config = {
      zramSwap = mkIf cfg.zram.enable {
        enable = true;
        algorithm = "zstd";
        memoryPercent = 40;
      };

      swapDevices = mkIf cfg.file.enable [
        {
          device = "/swap.img";
          size = 1024 * cfg.file.size;
          priority = 0;
          randomEncryption.enable = true;
        }
      ];

      # Make sure that all modules have been loaded before we try to create the swap
      # file. We need the loop module to be loaded.
      # Upstream PR: NixOS/nixpkgs#239163
      systemd.services = let
        mkSwapServiceOverride = swapDevice:
          lib.nameValuePair "mkswap-${swapDevice.deviceName}" {
            after = ["systemd-modules-load.service"];
          };
      in
        lib.listToAttrs (map mkSwapServiceOverride config.swapDevices);
    };
  }
