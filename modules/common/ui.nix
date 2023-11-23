{
  lib,
  pkgs,
  config,
  ...
}:
with lib; let
  isDarwin = pkgs.hostPlatform.isDarwin;
  isLinux = pkgs.hostPlatform.isLinux;
in {
  options.settings = {
    gui = {
      enable = mkOption {
        type = types.bool;
        default = isDarwin;
        description = "Enable the UI for this machine";
      };
    };
    windowManager = {
      enable = mkEnableOption "window manager";
    };
    keyMapping = {
      enable = mkEnableOption "Enable special key mappings";
    };
  };

  config = {
    fonts = let
      fonts = with pkgs; [
        meslo-lg
        meslo-lgs-nf
      ];
    in
      {
        fontDir.enable = true;
        # "fonts" renamed to "packages" in nixos, not not in nix-darwin
        fonts = lib.mkIf isDarwin fonts;
      }
      // (
        lib.optionalAttrs isLinux
        {
          packages = fonts;
        }
      );
  };
}
