{pkgs, ...}:
# TODO avoid this script in finding a programme that achieves the same goal e.g. fuseiso (but it doesn't seem to work in the machine)
pkgs.writeShellScriptBin "mount-image" ''
  set -eo pipefail
  IMG_FILE=$1
  MOUNT_POINT=$2
  mkdir -p $MOUNT_POINT
  LOOP=$(losetup --show -f -P $IMG_FILE)
  PART=$(ls $LOOP* | tail -n1)
  mount $PART $MOUNT_POINT
''
