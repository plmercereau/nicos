{
  lib,
  pkgs,
  config,
  ...
}:
with lib; let
  isDarwin = pkgs.hostPlatform.isDarwin;
in {
  options.settings.wm = lib.mkOption {
    type = types.bool;
    default = isDarwin;
    description = "Enable a window manager for this machine";
  };

  config =
    mkIf config.settings.wm
    {
      environment.systemPackages = with pkgs; [
        qbittorrent
        iina
      ];
    };
}
