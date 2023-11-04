{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (config.lib) ext_lib;
in {
  # # TODO check this out
  # boot.loader.raspberryPi.firmwareConfig = "dtoverlay=dwc2";
  # boot.kernelModules = ["libcomposite"];
  # boot.kernelParams = ["modules-load=dwc2"];

  # services.dnsmasq = {
  #   enable = true;
  #   settings = {
  #     domain-needed = true;
  #     bogus-priv = true;
  #     interface = "usb0";
  #     dhcp-range = ["10.213.0.100,10.213.0.200"];
  #   };
  #   resolveLocalQueries = false;
  # };

  #     option domain-name "domain.mobile";
  #     option subnet-mask 255.255.255.0;
  #     option broadcast-address 10.213.0.255;
  #     option domain-name-servers 9.9.9.9, 1.1.1.1;

  # systemd.services.usb-otg = {
  #   wantedBy = ["default.target"];
  #   script = builtins.readFile ./setup.sh;
  #   serviceConfig = {
  #     Type = "oneshot";
  #     RemainAfterExit = "yes";
  #   };
  # };

  # systemd.services.dnsmasq.after = ["usb-otg.service"];
  # systemd.services."network-addresses-usb0".after = ["usb-otg.service"];

  networking = {
    # dhcpcd.denyInterfaces = ["usb0"];
    # firewall.allowedUDPPorts = [
    #   67 # DHCP
    # ];

    # hosts = {
    #   "127.0.0.1" = ["mobile.domain.local"];
    #   "10.213.0.1" = ["mobile.domain.local"];
    # };
    # interfaces.usb0 = {
    #   useDHCP = false;
    #   ipv4.addresses = [
    #     {
    #       address = "10.213.0.1";
    #       prefixLength = 24;
    #     }
    #   ];
    # };
    # useDHCP = false;
  };

  # # TODO remove or merge into settings.server.enable
  # services.openssh.listenAddresses = [{addr = "10.66.6.1";}];
  # systemd.services.sshd.serviceConfig.RestartSec = "1s";
  # systemd.services.sshd.unitConfig.StartLimitIntervalSec = "0";

  # # TODO check this out: maybe a replacement to a swap partition?
  # zramSwap.enable = true;
  # zramSwap.algorithm = "zstd";

  # services.journald.extraConfig = "Storage=volatile";
  # powerManagement.cpuFreqGovernor = "schedutil";
}
