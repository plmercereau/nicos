{
  pkgs,
  lib,
  ...
}: let
  name = "yabai-extra";
  src = builtins.readFile ./script.nu;
  script = (pkgs.writeScriptBin name src).overrideAttrs (old: {
    buildCommand = "${old.buildCommand}\n patchShebangs $out";
  });
in
  pkgs.symlinkJoin {
    inherit name;
    paths = [script pkgs.nushell];
    buildInputs = [pkgs.makeWrapper];
    postBuild = "wrapProgram $out/bin/${name} --prefix PATH : $out/bin";
  }
