{
  pkgs,
  lib,
}: inputs @ {nixpkgs, ...}:
with lib; let
  flakeLib = import ../flake-lib.nix inputs;
  cli = pkgs.nicos;
  repo = "plmercereau/nicos";
  url = "https://github.com/${repo}";
  fileUrl = "${url}/blob/main";
  cliBin = "nix run github:${repo} --";
  warning = "AUTOGENERATED FILE, DO NOT MODIFY MANUALLY";
  src = ./..;
  docDest = "docs/reference";

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
      # ''${value.description} # TODO
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

  emptyMachine = nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    modules = flakeLib.nixosModules.default;
    specialArgs =
      flakeLib.specialArgs
      // {
        cluster = {
          hosts = {};
          projectRoot = null;
          builders.enable = false;
          wifi.enable = false;
          users.enable = false;
        };
      };
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
    name = "nicos-docgen";
    text = ''
      umask 022
      mkdir -p ${docDest}/machines
      cp -f ${nixosFile} ${docDest}/machines.mdx
      cp -f ${hardwareFile} ${docDest}/hardware.mdx
      awk '/%CONTENT%/{system("${cli}/bin/nicos docgen --bin-cmd \"${cliBin}\"");next}1' ${cliTemplate} > ${docDest}/cli.mdx
    '';
  }
