{
  lib,
  options,
  config,
  modulesPath,
  pkgs,
  srvos,
  ...
}: {
  imports = [
    # srvos.server
    ./disko.nix
  ];

  # TODO PR upstream in srvos https://github.com/nix-community/disko/pull/425
  boot.loader.grub.device = lib.mkForce "";

  # srvos defines 30s, that's too much
  boot.loader.timeout = lib.mkForce 5;

  # ! this is a hack to make sure that the ssh keys are not set by cloud-init, as we are provisioning them ourselves
  services.cloud-init.settings.cloud_config_modules = [
    "disk_setup"
    "mounts"
    "ssh-import-id"
    "set-passwords"
    "timezone"
    "disable-ec2-metadata"
    "runcmd"
    # "ssh"
  ];
  # * this doesn't work, but it would have been nicer to avoid the hack above
  #   services.cloud-init.settings.ssh_keys = {};
  #   services.cloud-init.settings.ssh_deletekeys = false;
}
