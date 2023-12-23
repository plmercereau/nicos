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
  # TODO split into two files darwin.nix and nixos.nix
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
