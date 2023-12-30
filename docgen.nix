inputs @ {
  nixpkgs,
  nix-darwin,
  ...
}: system: let
  inherit (nixpkgs) lib;
  pkgs = nixpkgs.legacyPackages.${system};
  inherit (import ./modules inputs) nixosModules darwinModules;

  flattenOptions = opt:
    if (opt ? "_type" && opt._type == "option")
    then {"${opt.__toString {}}" = opt;}
    else lib.foldlAttrs (acc: _: value: acc // (flattenOptions value)) {} opt;

  generateMdOptions = options:
    lib.mapAttrsToList (
      name: value: ''
        ## ${(value.__toString {})}

        ${value.description}

        |     |     |
        | --- | --- |
        | Type | <code>${value.type.description}</code> |
        ${lib.optionalString (value ? "default") "| Default | <code>${builtins.toJSON value.default}</code> |"}
        ${lib.optionalString (value ? "example") ''
          ### Example
          ```nix
          ${builtins.toJSON value.example}
          ```
        ''}
      ''
    )
    options;

  nixosSystem = nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    modules = nixosModules.default;
  };

  darwinSystem = nix-darwin.lib.darwinSystem {
    system = "aarch64-darwin";
    modules = darwinModules.default;
  };

  allNixosOptions = flattenOptions nixosSystem.options.settings;
  allDarwinOptions = flattenOptions darwinSystem.options.settings;
  commonOptions =
    lib.filterAttrs
    (name: value: (builtins.hasAttr name allNixosOptions) && (builtins.hasAttr name allDarwinOptions))
    (allNixosOptions // allDarwinOptions);
  nixosOptions = lib.filterAttrs (name: _: !(builtins.hasAttr name commonOptions)) allNixosOptions;
  darwinOptions = lib.filterAttrs (name: _: !(builtins.hasAttr name commonOptions)) allDarwinOptions;

  commonFile = builtins.toFile "common.mdx" ''
    ---
    title: "Common Options to NixOS and Darwin"
    sidebarTitle: "Common"
    icon: "share-nodes"
    ---
    {/* AUTOGENERATED FILE, DO NOT MODIFY MANUALLY */}
    ${builtins.concatStringsSep "\n" (generateMdOptions commonOptions)}
  '';

  nixosFile = builtins.toFile "nixos.mdx" ''
    ---
    title: "NixOS Options"
    sidebarTitle: "NixOS"
    icon: "linux"
    ---
    {/* AUTOGENERATED FILE, DO NOT MODIFY MANUALLY */}
    ${builtins.concatStringsSep "\n" (generateMdOptions nixosOptions)}
  '';

  darwinFile = builtins.toFile "darwin.mdx" ''
    ---
    title: "Darwin Options"
    sidebarTitle: "Darwin"
    icon: "apple"
    ---
    {/* AUTOGENERATED FILE, DO NOT MODIFY MANUALLY */}
    ${builtins.concatStringsSep "\n" (generateMdOptions darwinOptions)}
  '';
in
  pkgs.writeShellApplication {
    name = "docgen";
    text = ''
      mkdir -p docs/options
      cp ${commonFile} docs/options/common.mdx
      cp ${nixosFile} docs/options/nixos.mdx
      cp ${darwinFile} docs/options/darwin.mdx
    '';
  }
