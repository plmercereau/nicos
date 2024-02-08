# This module extends the official sd-image.nix with the following:
# - ability to add options to the config.txt firmware
# Original file: https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/installer/sd-card/sd-image.nix
{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}: let
  hostName = config.networking.hostName;
  cfg = config.sdImage;
  impermanence = config.settings.system.impermanence.enable;
in {
  imports = [
    (modulesPath + "/installer/sd-card/sd-image-aarch64.nix")
  ];

  options.sdImage = {
    # TODO not ideal, as config.txt cannot be updated after the sd card is created.
    # ? maybe we can update the file using an actication script?
    extraFirmwareConfig = with lib;
      mkOption {
        type = types.attrs;
        default = {};
        description = mdDoc ''
          Extra configuration to be added to config.txt.
        '';
      };
  };

  config = let
    persistenceSystemPath = "/var/nixos-system";
  in {
    settings.system.impermanence.persistentSystemPath = lib.mkIf impermanence persistenceSystemPath;

    nixpkgs.hostPlatform = "aarch64-linux";

    boot = {
      initrd.availableKernelModules = ["xhci_pci" "usbhid" "usb_storage"];
      loader = {
        grub.enable = false;
        generic-extlinux-compatible.enable = true;
      };
    };

    networking.wireless.enable = lib.mkDefault true;

    # * Modified so it works with impermanence: /nix-path-registration to $rootPath/nix-path-registration
    # * $rootPath is where the actual / filesystem is available, we have to use then delete the file.
    # See: https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/installer/sd-card/sd-image.nix#L258C7-L258C7
    boot.postBootCommands = ''
      # On the first boot do some maintenance tasks
      # TODO not the safest way to get the root path
      rootPath=$(findmnt -S /dev/disk/by-label/NIXOS_SD --first-only -O rw -o TARGET -n)
      if [ -f $rootPath/nix-path-registration ]; then
        set -euo pipefail
        set -x
        # Figure out device names for the boot device and root filesystem.
        rootPart=/dev/disk/by-label/NIXOS_SD
        bootDevice=$(lsblk -npo PKNAME $rootPart)
        partNum=$(lsblk -npo MAJ:MIN $rootPart | ${pkgs.gawk}/bin/awk -F: '{print $2}')

        # Resize the root partition and the filesystem to fit the disk
        echo ",+," | sfdisk -N$partNum --no-reread $bootDevice
        ${pkgs.parted}/bin/partprobe
        ${pkgs.e2fsprogs}/bin/resize2fs $rootPart

        # Register the contents of the initial Nix store
        ${config.nix.package.out}/bin/nix-store --load-db < $rootPath/nix-path-registration

        # nixos-rebuild also requires a "system" profile and an /etc/NIXOS tag.
        touch /etc/NIXOS
        ${config.nix.package.out}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system

        # Prevents this from running on later boots.
        rm -f $rootPath/nix-path-registration
      fi
    '';

    fileSystems = lib.mkIf impermanence {
      "/" = lib.mkForce {
        device = "none";
        fsType = "tmpfs";
        options = ["size=3G" "mode=755"]; # mode=755 so only root can write to those files
      };
      "${persistenceSystemPath}" = {
        device = "/dev/disk/by-label/NIXOS_SD";
        fsType = "ext4";
        options = ["noatime"];
        # https://search.nixos.org/options?channel=23.05&from=0&size=50&sort=relevance&type=packages&query=neededForBoot
        neededForBoot = true;
      };
      "/nix" = {
        device = "${persistenceSystemPath}/nix";
        options = ["bind"];
      };
      "/boot" = {
        device = "${persistenceSystemPath}/boot";
        options = ["bind"];
        neededForBoot = true;
      };
    };

    # bzip2 compression takes loads of time with emulation, skip it. Enable this if you're low on space.
    sdImage = {
      compressImage = false;
      imageName = "${hostName}.img";
      populateFirmwareCommands =
        lib.mkIf ((lib.length (lib.attrValues cfg.extraFirmwareConfig)) > 0)
        (
          let
            # Convert the set into a string of lines of "key=value" pairs.
            keyValueMap = name: value: name + "=" + toString value;
            keyValueList = lib.mapAttrsToList keyValueMap cfg.extraFirmwareConfig;
            extraFirmwareConfigString = lib.concatStringsSep "\n" keyValueList;
          in
            lib.mkAfter
            ''
              config=firmware/config.txt
              # The initial file has just been created without write permissions. Add them to be able to append the file.
              chmod u+w $config
              echo "\n# Extra configuration" >> $config
              echo "${extraFirmwareConfigString}" >> $config
              chmod u-w $config
            ''
        );
    };
  };
}
