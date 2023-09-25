{
  lib,
  pkgs,
  ...
}: {
  programs.helix = {
    enable = true;
  };

  # TODO should be ideally common to every editor?
  home.packages = with pkgs; [
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
  ];
}
