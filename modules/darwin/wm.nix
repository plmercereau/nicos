{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
with lib; let
  platform = config.settings.hardwarePlatform;
  platforms = config.settings.hardwarePlatforms;
in {
  system.defaults = {
    # Use F1, F2, etc. keys as standard function keys.
    NSGlobalDomain."com.apple.keyboard.fnState" = true;
  };

  system.keyboard = {
    enableKeyMapping = true;
    # Whether to remap the Caps Lock key to Control.
    remapCapsLockToControl = true;
  };

  environment.etc = {
    # Don't ask from confirmation when reloading yabai sa
    "sudoers.d/10-yabai".text = ''
      %admin ALL=(root) NOPASSWD: /run/current-system/sw/bin/yabai --load-sa
    '';
  };

  services.yabai = {
    enable = true;
    package = pkgs.yabai;
    enableScriptingAddition = true;
    # https://www.josean.com/posts/yabai-setup
    config = let
      padding = 0;
    in {
      layout = "bsp";
      focus_follows_mouse = "autofocus";
      mouse_follows_focus = "on";
      mouse_modifier = "fn";
      mouse_action1 = "resize";
      mouse_action2 = "move";
      # New window spawns to the right if vertical split, or bottom if horizontal split
      window_placement = "second_child";
      window_opacity = "off";
      top_padding = padding;
      bottom_padding = padding;
      left_padding = padding;
      right_padding = padding;
      window_gap = 3;
    };

    # TODO create a 7th space when using only one display, and move this space to the second display when plugged.
    # When unplugged, move back windows to the 7th space.
    # Something like this: yabai -m signal --add event=display_removed action="yabai xxx"
    extraConfig = ''
      # Reload sa when the dock restarts
      yabai -m signal --add event=dock_did_restart action="sudo yabai --load-sa"
    '';
  };

  # * fyi https://github.com/NixOS/nixpkgs/issues/246740
  services.skhd = {
    enable = true;
    skhdConfig = ''
      fn - r: pkill yabai && \
        ${pkgs.skhd}/bin/skhd -r && \
        osascript -e 'display notification  "restart yabai and reload skhd"'

      ### CHANGE FOCUS ###
      # change focus between external displays (left and right)
      f11: yabai -m display --focus west
      f12: yabai -m display --focus east

      # change focus between spaces
      f1 : yabai -m space --focus 1
      f2 : yabai -m space --focus 2
      f3 : yabai -m space --focus 3
      f4 : yabai -m space --focus 4
      f5 : yabai -m space --focus 5
      f6 : yabai -m space --focus 6

      # change window focus within space
      alt + cmd - j : yabai -m window --focus south
      alt + cmd - k : yabai -m window --focus north
      alt + cmd - h : yabai -m window --focus west
      alt + cmd - l : yabai -m window --focus east

      ### ARRANGE WINDOWS ###
      # rotate layout clockwise
      alt + cmd - r : yabai -m space --rotate 270

      # flip along y-axis
      alt + cmd - y : yabai -m space --mirror y-axis

      # flip along x-axis
      alt + cmd - x : yabai -m space --mirror x-axis

      # toggle window float
      alt + cmd - t : yabai -m window --toggle float --grid 4:4:1:1:2:2
      # maximize a window
      alt + cmd - m : yabai -m window --toggle zoom-fullscreen

      # balance out tree of windows (resize to occupy same area)
      alt + cmd - e : yabai -m space --balance

      # swap windows
      ctrl + cmd - j : yabai -m window --swap south
      ctrl + cmd - k : yabai -m window --swap north
      ctrl + cmd - h : yabai -m window --swap west
      ctrl + cmd - l : yabai -m window --swap east

      # move window and split
      ctrl + alt - j : yabai -m window --warp south
      ctrl + alt - k : yabai -m window --warp north
      ctrl + alt - h : yabai -m window --warp west
      ctrl + alt - l : yabai -m window --warp east


      # move window to prev and next space
      alt + cmd - p : yabai -m window --space prev;
      alt + cmd - n : yabai -m window --space next;

      # move window to space #
      cmd - f1 : yabai -m window --space 1;
      cmd - f2 : yabai -m window --space 2;
      cmd - f3 : yabai -m window --space 3;
      cmd - f4 : yabai -m window --space 4;
      cmd - f5 : yabai -m window --space 5;
      cmd - f6 : yabai -m window --space 6;

      # move window to display left and right
      cmd - f11 : yabai -m window --display west
      cmd - f12 : yabai -m window --display east

      # move window to space and follow focus
      alt + cmd - f1 : yabai -m window --space 1; yabai -m space --focus 1
      alt + cmd - f2 : yabai -m window --space 2; yabai -m space --focus 2
      alt + cmd - f3 : yabai -m window --space 3; yabai -m space --focus 3
      alt + cmd - f4 : yabai -m window --space 4; yabai -m space --focus 4
      alt + cmd - f5 : yabai -m window --space 5; yabai -m space --focus 5
      alt + cmd - f6 : yabai -m window --space 6; yabai -m space --focus 6

      # move window to display left and right and follow focus
      alt + cmd - f11 : yabai -m window --display west; yabai -m display --focus west;
      alt + cmd - f12 : yabai -m window --display east; yabai -m display --focus east;
    '';
  };
}
