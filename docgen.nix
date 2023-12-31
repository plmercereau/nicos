inputs @ {
  nixpkgs,
  nix-darwin,
  ...
}: system: let
  path = "docs/reference";
  warning = "{/* AUTOGENERATED FILE, DO NOT MODIFY MANUALLY */}";
  inherit (nixpkgs) lib;
  pkgs = nixpkgs.legacyPackages.${system};
  inherit (import ./modules inputs) nixosModules darwinModules;

  flattenOptions = opt:
    if (opt ? "_type" && opt._type == "option")
    then
      (
        if (opt ? "internal" && opt.internal)
        then {}
        else {"${opt.__toString {}}" = opt;}
      )
    else lib.foldlAttrs (acc: _: value: acc // (flattenOptions value)) {} opt;

  generateMdOptions = options:
    lib.mapAttrsToList (
      name: value: ''
        <ResponseField
            name="${(value.__toString {})}"
            type="${value.type.description}"
            ${lib.optionalString (value ? "default" && value.default != null) "default={${builtins.toJSON value.default}}"}
            ${lib.optionalString (!value ? "default") "required"}
            >
          ${value.description}
          ${lib.optionalString (value ? "example") ''
          ```nix Example
          ${builtins.toJSON value.example}
          ```
        ''}
        </ResponseField>
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

  commonFile = builtins.toFile "common.mdx" ''
    ---
    title: "Common options to NixOS and Darwin"
    sidebarTitle: "Common"
    icon: "share-nodes"
    ---
    ${warning}
    ${builtins.concatStringsSep "\n" (generateMdOptions commonOptions)}
  '';

  nixosFile = let
    nixosOptions = lib.filterAttrs (name: _: !(builtins.hasAttr name commonOptions)) allNixosOptions;
  in
    builtins.toFile "nixos.mdx" ''
      ---
      title: "NixOS options"
      sidebarTitle: "NixOS"
      icon: "linux"
      ---
      ${warning}
      ${builtins.concatStringsSep "\n" (generateMdOptions nixosOptions)}
    '';

  darwinFile = let
    darwinOptions = lib.filterAttrs (name: _: !(builtins.hasAttr name commonOptions)) allDarwinOptions;
  in
    builtins.toFile "darwin.mdx" ''
      ---
      title: "Darwin options"
      sidebarTitle: "Darwin"
      icon: "apple"
      ---
      ${warning}
      ${builtins.concatStringsSep "\n" (generateMdOptions darwinOptions)}
    '';

  hardwareFile = builtins.toFile "hardware.mdx" ''
    ---
    title: "Preconfigured hardware modules"
    sidebarTitle: "Hardware modules"
    icon: "microchip"
    ---
    ${warning}
    <RequestExample>

    ```nix hosts-nixos/example.nix
    {hardware, ...}: {
      imports = [hardware.hetzner-x86];
    }
    ```

    </RequestExample>
    <ResponseExample>

    ```nix darwin-hosts/example.nix
    {hardware, ...}: {
      imports = [hardware.m1];
    }
    ```

    </ResponseExample>

    | System | Name | Description |
    | ------ | ---- | ----------- |
    ${builtins.concatStringsSep "\n" (lib.mapAttrsToList (name: value: "| Darwin | ${name} | ${value.label} |") (import ./hardware/darwin))}
    ${builtins.concatStringsSep "\n" (lib.mapAttrsToList (name: value: "| NixOS  | ${name} | ${value.label} |") (import ./hardware/nixos))}
  '';
in
  pkgs.writeShellApplication {
    name = "docgen";
    text = ''
      mkdir -p ${path}
      cp -f ${commonFile} ${path}/machines/common.mdx
      cp -f ${nixosFile} ${path}/machines/nixos.mdx
      cp -f ${darwinFile} ${path}/machines/darwin.mdx
      cp -f ${hardwareFile} ${path}/hardware.mdx
    '';
  }
