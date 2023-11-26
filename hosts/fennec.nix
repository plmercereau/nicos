{
  config,
  modulesPath,
  pkgs,
  lib,
  ...
}: let
  common = "common";
in {
  imports = [
    ../hardware/nuc.nix
    (modulesPath + "/installer/scan/not-detected.nix") # ?
  ];

  # TODO remote builder

  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.displayManager.gdm.settings = {};
  services.xserver.desktopManager.gnome.enable = true;

  # Disable the GNOME3/GDM auto-suspend feature that cannot be disabled in GUI!
  # If no user is logged in, the machine will power down after 20 minutes.
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  environment.gnome.excludePackages =
    (with pkgs; [
      gnome-tour
    ])
    ++ (with pkgs.gnome; [
      cheese # webcam tool
      gnome-music
      gnome-calendar
      gnome-logs
      gnome-shell
      gnome-terminal
      gnome-bluetooth
      gnome-power-manager
      gnome-nettool
      gnome-contacts
      gnome-characters
      gedit # text editor
      epiphany # web browser
      geary # email reader
      evince # document viewer
      totem # video player
      tali # poker game
      simple-scan
      iagno # go game
      hitori # sudoku game
      atomix # puzzle game
    ]);
  environment.systemPackages = with pkgs; [
    gnomeExtensions.appindicator
  ];

  services.udev.packages = with pkgs; [gnome.gnome-settings-daemon];
  # Disable the network manager for the wifi interface
  networking.networkmanager.unmanaged = ["wlo1"];

  services.nginx.enable = true;
  services.blocky.enable = true;
  # ! do not try this as blocky is not using upstream DNS servers to resolve blacklist/whitlist
  # It means on startup, it looks for the DNS name through 127.0.0.1 but it is not available as blocky is not started yet
  # networking.nameservers = ["127.0.0.1"]; # Use self AdGuardHome as DNS server

  services.transmission.enable = true;
  services.jellyfin.enable = true;

  # TODO https://nixos.wiki/wiki/OneDrive
  # ? remote "online" mount: onedriver: https://github.com/jordanisaacs/dotfiles/blob/42c02301984a1e2c4da6f3a88914545feda00360/modules/users/office365/default.nix#L52
  services.onedrive.enable = true;
  # TODO one account for pilou, one common account
  # # * Common OneDrive configuration. The OneDrive systemd service must be enabled manually
  # # * See: https://nixos.wiki/wiki/OneDrive
  # sudo -u common onedrive
  # ! tricky: https://stackoverflow.com/questions/34167257/can-i-control-a-user-systemd-using-systemctl-user-after-sudo-su-myuser
  # sudo systemctl --user -M common@ enable onedrive@onedrive.service
  # sudo systemctl --user -M common@ start onedrive@onedrive.service
  users.users."${common}" = {
    isSystemUser = true;
    group = common;
    homeMode = "770";
    createHome = true;
    home = "/var/lib/${common}";
  };
  users.groups."${common}" = {};

  home-manager.users."${common}" = {
    home.stateVersion = "23.05";
    home.file.".config/onedrive/config".text = ''
      sync_dir = "~"
      skip_file = "~*|.~*|*.tmp"
      log_dir = "/var/log/onedrive/"
      skip_symlinks = "false"
      skip_dotfiles = "true"
      sync_dir_permissions = "770"
      sync_file_permissions = "660"
    '';
  };

  # !!!!!!!!!! SAMBA !!!!!!!!
  services.samba = {
    enable = true;

    shares = {
      common = {
        path = "/var/lib/${common}";
        comment = "Common files";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mask" = "0660";
        "directory mask" = "0770";
        "force user" = common;
        "force group" = common;
      };
      scanner = {
        path = "/var/lib/scanner";
        comment = "Scanner";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "yes";
        "create mask" = "0660";
        "directory mask" = "0770";
        "force user" = "scanner";
        "force group" = common;
      };
    };
  };

  # ! add the user to samba: sudo smbpasswd -a scanner
  users.users.scanner = {
    isSystemUser = true;
    group = common;
    homeMode = "770";
    createHome = true;
    home = "/var/lib/scanner";
  };

  # home-manager.users.gdm = {
  #   home.stateVersion = "23.05";
  #   home.file.".config/monitors.xml".text = ''
  #     <monitors version="2">
  #       <configuration>
  #         <logicalmonitor>
  #           <x>0</x>
  #           <y>0</y>
  #           <scale>2</scale>
  #           <primary>yes</primary>
  #           <monitor>
  #             <monitorspec>
  #               <connector>DP-3</connector>
  #               <vendor>HPN</vendor>
  #               <product>HP Z27</product>
  #               <serial>CN4913011H</serial>
  #             </monitorspec>
  #             <mode>
  #               <width>3840</width>
  #               <height>2160</height>
  #               <rate>59.997</rate>
  #             </mode>
  #           </monitor>
  #         </logicalmonitor>
  #       </configuration>
  #     </monitors>
  #   '';
  # };

  # ! Kids configuration
  settings.users.users.kids.enable = lib.mkForce true;
  home-manager.users.kids = import ../home-manager/kids.nix;
  # the pilou user can access to the kids user with his ssh keys
  users.users.kids.openssh.authorizedKeys.keys = config.users.users.pilou.openssh.authorizedKeys.keys;

  # TODO configure
  services.malcontent.enable = true;

  users.users.pilou.extraGroups = with config.services; [transmission.group jellyfin.group common];

  # TODO profile picture
  # https://nixos.wiki/wiki/GNOME

  # * Autologin
  services.xserver.displayManager.autoLogin.enable = true;
  services.xserver.displayManager.autoLogin.user = "kids";
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;
}