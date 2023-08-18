## SD image

Configuration required to build a system into an SD image:

-   Raspberry Pi Zero 2
-   Raspberry Pi 4
-   the `sd-image.nix` file is a patch of the original sd-image builder to:
    -   make it work with the Zero 2
    -   add an optional swap partition
    -   pass on `config.txt` options
