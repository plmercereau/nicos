{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  inherit (config.lib) ext_lib;
  cfg = config.settings.users;
in {
  config = {
    home-manager.users = let
      mkHomeManagerUser = _: user: let
        userConfig = config.home-manager.users.${_};
        enable = config.home-manager.users.${_}.programs.helix.enable;
        defaultEditor = enable && userConfig.programs.helix.defaultEditor;
      in {
        # TODO should be ideally common to every editor?
        home.packages = mkIf enable (with pkgs; [
          # Formatting
          # TODO enable it in helix: https://github.com/kamadorueda/alejandra
          alejandra

          # Debugging stuff
          # lldb

          # Language servers
          # clang-tools # C-Style
          # cmake-language-server # Cmake, pray to never need to use it
          # gopls # Go
          nil # Nix
          # rust-analyzer # Rust
          # texlab # LaTeX
          # zls # Zig
          # ols # Odin
          # elixir_ls # Elixir
          # sourcekit-lsp # Swift & Obj-C

          # ocamlPackages.ocaml-lsp # OCaml

          # haskellPackages.haskell-language-server # Haskell

          nodePackages.typescript-language-server # Typescript
          nodePackages.vim-language-server # Vim
          nodePackages.yaml-language-server # YAML / JSON

          # luajitPackages.lua-lsp # Lua
        ]);
      };

      mkHomeManagerUsers = ext_lib.compose [
        (mapAttrs mkHomeManagerUser)
        # TODO recursion issue
        # (lib.filterAttrs (_: user: trace "ici" config.home-manager.users.${_}.programs.vscode.enable))
        ext_lib.filterEnabled
      ];
    in
      mkHomeManagerUsers cfg.users;
  };
}
