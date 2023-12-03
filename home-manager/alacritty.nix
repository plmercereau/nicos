{pkgs, ...}: {
  programs.alacritty = {
    enable = true;
    settings = {
      window = {
        option_as_alt = "Both"; # Make `Option` key behave as `Alt` (macOS only)
      };
      font = {
        size = 16;
        # Required when using zsh + powerlevel10k?
        normal.family = "MesloLGS NF";
      };
      # gruvbox: https://gist.github.com/kamek-pf/2eae4f570061a97788a8a9ca4c893797
      colors = {
        # Default colors
        primary = {
          background = "0x282828";
          foreground = "0xdfbf8e";

          # dim_foreground = "0xdbdbdb";
          # bright_foreground = "0xd9d9d9";
          # dim_background = "0x202020";
          # bright_background = "0x3a3a3a";
        };
        # # Cursor colors
        # cursor = {
        #   text = "0x2c2c2c";
        #   cursor = "0xd9d9d9";
        # };
        # Normal colors
        normal = {
          black = "0x665c54";
          red = "0xea6962";
          green = "0xa9b665";
          yellow = "0xe78a4e";
          blue = "0x7daea3";
          magenta = "0xd3869b";
          cyan = "0x89b482";
          white = "0xdfbf8e";
        };
        # Bright colors
        bright = {
          black = "0x928374";
          red = "0xea6962";
          green = "0xa9b665";
          yellow = "0xe3a84e";
          blue = "0x7daea3";
          magenta = "0xd3869b";
          cyan = "0x89b482";
          white = "0xdfbf8e";
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
}
