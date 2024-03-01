{
  pkgs,
  lib,
  ...
}:
with lib; {
  imports = [
    ./git
    ./impermanence.nix
    ./kubernetes
    ./local-server
    ./lib.nix
    ./networking.nix
    ./nix.nix
    # ./nix-builder.nix
    ./prometheus
    ./ssh.nix
    ./swap.nix
    ./users.nix
  ];
  system.stateVersion = "23.11";

  programs.bash.enableCompletion = true;

  # Packages that should always be available for manual intervention
  environment.systemPackages = with pkgs; [curl e2fsprogs];

  services = {
    # https://man7.org/linux/man-pages/man8/fstrim.8.html
    fstrim.enable = true;

    # Avoid pulling in unneeded dependencies
    udisks2.enable = mkDefault false;

    # NTP time sync.
    timesyncd = {
      enable = true;
      servers = mkDefault [
        "0.nixos.pool.ntp.org"
        "1.nixos.pool.ntp.org"
        "2.nixos.pool.ntp.org"
        "3.nixos.pool.ntp.org"
        "time.windows.com"
        "time.google.com"
      ];
    };

    htpdate = {
      enable = true;
      servers = ["www.kernel.org" "www.google.com" "www.cloudflare.com"];
    };
  };
}
