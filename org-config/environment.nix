{pkgs, ...}: {
  nixpkgs.config.allowUnfree = true;

  # Common config for every machine (NixOS or Darwin)
  environment.systemPackages = with pkgs; [
    curl
    e2fsprogs
    file
    jq
    killall
    nnn # file browser
    speedtest-cli # Command line speed test utility
    unzip
    wget
  ];
}
