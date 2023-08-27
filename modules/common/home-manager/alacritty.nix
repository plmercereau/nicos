{ config, lib, pkgs, ... }:

with lib;

let
  inherit (config.lib) ext_lib;
  cfg = config.settings.users;
in
{

  config = {
    home-manager.users =
      let
        mkHomeManagerUser = _: user:
          let
            enable = config.home-manager.users.${_}.programs.alacritty.enable;
          in
          {
            programs.alacritty.settings = mkIf enable {
              font = {
                size = 16;
                # TODO only if the user is using zsh + powerlevel10k?
                normal.family = "MesloLGS NF";
              };
              colors = {
                # Default colors
                primary = {
                  background = "0x2c2c2c";
                  foreground = "0xd6d6d6";

                  dim_foreground = "0xdbdbdb";
                  bright_foreground = "0xd9d9d9";
                  dim_background = "0x202020";
                  bright_background = "0x3a3a3a";
                };
                # Cursor colors
                cursor = {
                  text = "0x2c2c2c";
                  cursor = "0xd9d9d9";
                };
                # Normal colors
                normal = {
                  black = "0x1c1c1c";
                  red = "0xbc5653";
                  green = "0x909d63";
                  yellow = "0xebc17a";
                  blue = "0x7eaac7";
                  magenta = "0xaa6292";
                  cyan = "0x86d3ce";
                  white = "0xcacaca";
                };
                # Bright colors
                bright = {
                  black = "0x636363";
                  red = "0xbc5653";
                  green = "0x909d63";
                  yellow = "0xebc17a";
                  blue = "0x7eaac7";
                  magenta = "0xaa6292";
                  cyan = "0x86d3ce";
                  white = "0xf7f7f7";
                };

                # Dim colors
                dim = {
                  black = "0x232323";
                  red = "0x74423f";
                  green = "0x5e6547";
                  yellow = "0x8b7653";
                  blue = "0x556b79";
                  magenta = "0x6e4962";
                  cyan = "0x5c8482";
                  white = "0x828282";
                };
              };
            };
          };

        mkHomeManagerUsers = ext_lib.compose [
          (mapAttrs mkHomeManagerUser)
          ext_lib.filterEnabled
        ];
      in
      mkHomeManagerUsers cfg.users;
  };
}


