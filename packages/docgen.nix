pkgs: inputs @ {
  nixpkgs,
  agenix,
  disko,
  impermanence,
  home-manager,
  srvos,
  ...
}:
with nixpkgs.lib; let
  cli = import ./cli pkgs inputs;
  repo = "plmercereau/nicos";
  url = "https://github.com/${repo}";
  fileUrl = "${url}/blob/main";
  cliBin = "nix run github:${repo} --";
  warning = "AUTOGENERATED FILE, DO NOT MODIFY MANUALLY";
  src = ./..;
  docDest = "docs/reference";
  inherit (nixpkgs) lib;

  fromTemplate = template: contents: let
    template_file = readFile (src + "/docs/${template}");
  in
    builtins.toFile "result.mdx" (
      replaceStrings
      ["%CONTENT%" "%WARNING%"]
      [contents warning]
      template_file
    );

  flattenOptions = opt:
    if (opt ? "_type" && opt._type == "option")
    then optionalAttrs (!(opt ? "internal" && opt.internal)) {${opt.__toString {}} = opt;} // (flattenOptions (opt.type.getSubOptions opt.loc))
    else foldlAttrs (acc: _: value: acc // (flattenOptions value)) {} opt;

  generateMdOptions = options: let
    list =
      mapAttrsToList (
        name: value: ''
          <h4 id="${(value.__toString {})}">
            <span class="hidden">`${(value.__toString {})}`</span>
          </h4>

          <ResponseField
              name="${(value.__toString {})}"
              type="${replaceStrings [''"''] ["&#34;"] value.type.description}"
              ${optionalString (value ? "default" && value.default != null) "default={${strings.toJSON value.default}}"}
              ${optionalString (!value ? "default") "required"}
              >
          ${value.description}
          ${optionalString (value ? "example") ''
            ```nix Example
            ${strings.toJSON value.example}
            ```
          ''}
          Declared in ${concatStringsSep ", " (map (d: let
            file = removePrefix "${toString src}/" (d.file);
          in "[${file}](${fileUrl}/${file}#L${toString d.line})")
          value.declarationPositions)}.
          </ResponseField>
        ''
      )
      options;
  in (concatStringsSep "\n" list);

  emptyMachine = nixosSystem {
    system = "aarch64-linux";
    modules = [
      agenix.nixosModules.default
      disko.nixosModules.disko
      impermanence.nixosModules.impermanence
      home-manager.nixosModules.home-manager
      # TODO create a "srvos" special argument, then import srvos.nixosModules.mixins-trusted-nix-caches from nicos modules
      srvos.nixosModules.mixins-trusted-nix-caches
      ../modules
    ];
  };

  nixosOptions = flattenOptions emptyMachine.options.settings;

  nixosFile = fromTemplate "templates/machines.mdx" (generateMdOptions nixosOptions);

  hardwareFile =
    fromTemplate "templates/hardware.mdx"
    ''
      ${concatStringsSep "\n" (mapAttrsToList (name: value: "| ${name} | ${value.label} |") (import ../hardware).recap)}
    '';

  # Replace the %WARNINNG% but keep the %CONTENT% for the awk command
  cliTemplate = fromTemplate "templates/cli.mdx" "%CONTENT%";
in
  pkgs.writeShellApplication {
    name = "docgen";
    text = ''
      umask 022
      mkdir -p ${docDest}/machines
      cp -f ${nixosFile} ${docDest}/machines.mdx
      cp -f ${hardwareFile} ${docDest}/hardware.mdx
      awk '/%CONTENT%/{system("${cli}/bin/nicos docgen --bin-cmd \"${cliBin}\"");next}1' ${cliTemplate} > ${docDest}/cli.mdx
    '';
  }
