{
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./common.nix
  ];

  # TODO monitor dconf settings and add them here e.g. gnome extensions
  dconf.settings = {
    "org/gnome/desktop/lockdown" = {
      # Prevent the user from logging out
      disable-log-out = true;
    };
  };

  home.packages = with pkgs; ([
      gcompris
      tuxpaint # TODO config file https://tuxpaint.org/docs/en/html/OPTIONS.html#cfg-file
      colobot
      extremetuxracer
      frozen-bubble
      tuxtype
      #   kstars # awful UI
      libsForQt5.marble
      #   libsForQt5.kturtle # a bit too early
      #   celestia # Real-time 3D simulation of space -> GTK, not nice
      #   frozen-bubble # complicated to make it work - and needs internet...
      superTux
      superTuxKart
      # freeciv # ? too early?
      # lutris # ? see later
      # iina # TODO vlc, as iina is not available for linux. Or: https://github.com/mpv-player/mpv/wiki/Applications-using-mpv
      openshot-qt # TODO find the simplest video editor: https://filmora.wondershare.com/video-editor/free-linux-video-editor.html
    ]
    ++ (with gnome; [
      iagno # go game
      hitori # sudoku game
      atomix # puzzle game
      sushi # preview files
      gedit # text editor
      gpaste # clipboard manager
      simple-scan # scanner
      gnome-chess
    ]));
}
