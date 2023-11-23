{
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./common.nix
  ];

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
      tuxtype
      #   kstars # awful UI
      libsForQt5.marble
      #   libsForQt5.kturtle # a bit too early
      #   celestia # Real-time 3D simulation of space -> GTK, not nice
      #   frozen-bubble # complicated to make it work - and needs internet...
      superTux
      superTuxKart
      freeciv
      lutris
    ]
    ++ (with gnome; [
      iagno # go game
      hitori # sudoku game
      atomix # puzzle game
    ]));
}
