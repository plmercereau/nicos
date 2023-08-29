{
  lib,
  pkgs,
  ...
}:
with lib;
/*
We structure this file as one big let expression from which we will then
inherit all the defined functions.
The main reason is that let expressions are recursive while attribute sets
are not, so within a let expression definitions can recursively reference
each other independent of the order in which they have been defined.
*/
  let
    inherit
      (import ../../lib.nix {inherit lib;})
      compose
      applyTwice
      filterEnabled
      concatMapAttrsToList
      recursiveMerge
      stringNotEmpty
      nixosVersionOf
      ;

    /*
    Find duplicate elements in a list in O(n) time

    Example:
      find_duplicates [ 1 2 2 3 4 4 4 5 ]
      => [ 2 4 ]
    */
    find_duplicates = let
      /*
        Function to use with foldr
      Given an element and a set mapping elements (as Strings) to booleans,
      it will add the element to the set with a value of:
        - false if the element was not previously there, and
        - true  if the element had been added already
      The result after folding, is a set mapping duplicate elements to true.
      */
      update_duplicates_set = el: set: let
        is_duplicate = el: hasAttr (toString el);
      in
        set // {${toString el} = is_duplicate el set;};
    in
      compose [
        attrNames # return the name only
        (filterAttrs (flip const)) # filter on trueness of the value
        (foldr update_duplicates_set {}) # fold to create the duplicates set
      ];

    /*
      Function to find duplicate mappings in a list of attrsets
    *
    *   find_duplicate_mappings [ { "foo" = 1; "bar" = 2; } { "foo" = 3; } ]
    *     -> { "foo" = [ 1 3 ] }
    */
    find_duplicate_mappings = let
      # For every element seen, we add an entry to the set
      update_duplicates_set = el: set: set // {${toString el} = true;};
    in
      compose [
        (filterAttrs (_: v: length v >= 2)) # filter on users having 2 or more profiles
        (mapAttrs (_: attrNames)) # collect just the different profile names
        (foldAttrs update_duplicates_set {}) # collect the values for the different keys
      ];

    /*
    A type for host names, host names consist of:
     * a first character which is an upper or lower case ascii character
     * followed by zero or more of: dash (-), upper case ascii, lower case ascii, digit
     * followed by an upper or lower case ascii character or a digit
    */
    host_name_type =
      types.strMatching "^[[:upper:][:lower:]][-[:upper:][:lower:][:digit:]]*[[:upper:][:lower:][:digit:]]$";
    empty_str_type =
      types.strMatching "^$"
      // {
        description = "empty string";
      };
    pub_key_type = let
      key_data_pattern = "[[:lower:][:upper:][:digit:]\\/+]";
      key_patterns = let
        /*
            These prefixes consist out of 3 null bytes followed by a byte giving
        the length of the name of the key type, followed by the key type itself,
        and all of this encoded as base64.
        So "ssh-ed25519" is 11 characters long, which is \x0b, and thus we get
          b64_encode(b"\x00\x00\x00\x0bssh-ed25519")
        For "ecdsa-sha2-nistp256", we have 19 chars, or \x13, and we get
          b64encode(b"\x00\x00\x00\x13ecdsa-sha2-nistp256")
        For "ssh-rsa", we have 7 chars, or \x07, and we get
          b64encode(b"\x00\x00\x00\x07ssh-rsa")
        */
        ed25519_prefix = "AAAAC3NzaC1lZDI1NTE5";
        nistp256_prefix = "AAAAE2VjZHNhLXNoYTItbmlzdHAyNTY";
        rsa_prefix = "AAAAB3NzaC1yc2E";
      in {
        ssh-ed25519 = "^ssh-ed25519 ${ed25519_prefix}${key_data_pattern}{48}$";
        ecdsa-sha2-nistp256 = "^ecdsa-sha2-nistp256 ${nistp256_prefix}${key_data_pattern}{108}=$";
        # We require 2048 bits minimum. This limit might need to be increased
        # at some point since 2048 bit RSA is not considered very secure anymore
        ssh-rsa = "^ssh-rsa ${rsa_prefix}${key_data_pattern}{355,}={0,2}$";
      };
      pub_key_pattern = concatStringsSep "|" (attrValues key_patterns);
      description =
        ''valid ${concatStringsSep " or " (attrNames key_patterns)} key, ''
        + ''meaning a string matching the pattern ${pub_key_pattern}'';
    in
      types.strMatching pub_key_pattern // {inherit description;};

    ifPathExists = path: optional (builtins.pathExists path) path;

    traceImportJSON = compose [
      (filterAttrsRecursive (k: _: k != "_comment"))
      importJSON
      (traceValFn (f: "Loading file ${toString f}..."))
    ];

    # If the given option exists in the given path, then we return the option,
    # otherwise we return null.
    # This can be used to optionally set options:
    #   config.foo.bar = {
    #     ${keyIfExists config.foo.bar "baz"} = valueIfBazOptionExists;
    #   };
    keyIfExists = path: option:
      if hasAttr option path
      then option
      else null;

    # Prepend a string with a given number of spaces
    # indentStr :: Int -> String -> String
    indentStr = n: str: let
      spacesN = compose [concatStrings (genList (const " "))];
    in
      (spacesN n) + str;

    mkSudoStartServiceCmds = {
      serviceName,
      extraOpts ? ["--system"],
    }: let
      optsStr = concatStringsSep " " extraOpts;
      mkStartCmd = service: "${pkgs.systemd}/bin/systemctl ${optsStr} start ${service}";
    in [
      (mkStartCmd serviceName)
      (mkStartCmd "${serviceName}.service")
    ];

    reset_git = {
      url,
      branch,
      git_options,
      indent ? 0,
    }: let
      git = "${pkgs.git}/bin/git";
      mkOptionsStr = concatStringsSep " ";
      mkGitCommand = git_options: cmd: "${git} ${mkOptionsStr git_options} ${cmd}";
      mkGitCommandIndented = indent: git_options:
        compose [(indentStr indent) (mkGitCommand git_options)];
    in
      concatMapStringsSep "\n" (mkGitCommandIndented indent git_options) [
        ''remote set-url origin "${url}"''
        # The following line is only used to avoid the warning emitted by git.
        # We will reset the local repo anyway and remove all local changes.
        ''config pull.rebase true''
        ''fetch origin ${branch}''
        ''checkout ${branch} --''
        ''reset --hard origin/${branch}''
        ''clean -d --force''
        ''pull''
      ];

    clone_and_reset_git = {
      config,
      clone_dir,
      github_repo,
      branch,
      git_options ? [],
      indent ? 0,
    }: let
      repo_url = config.settings.system.org.repo_to_url github_repo;
    in
      optionalString (config != null) ''
        if [ ! -d "${clone_dir}" ] || [ ! -d "${clone_dir}/.git" ]; then
          if [ -d "${clone_dir}" ]; then
            # The directory exists but is not a git clone
            ${pkgs.coreutils}/bin/rm --recursive --force "${clone_dir}"
          fi
          ${pkgs.coreutils}/bin/mkdir --parent "${clone_dir}"
          ${pkgs.git}/bin/git clone "${repo_url}" "${clone_dir}"
        fi
        ${reset_git {
          inherit branch indent;
          url = repo_url;
          git_options = git_options ++ ["-C" ''"${clone_dir}"''];
        }}
      '';

    mkDeploymentService = {
      config,
      enable ? true,
      deploy_dir_name,
      github_repo,
      git_branch ? "main",
      pre-compose_script ? "deploy/pre-compose.sh",
      extra_script ? "",
      restart ? false,
      force_build ? false,
      docker_compose_files ? ["docker-compose.yml"],
    }: let
      secrets_dir = config.settings.system.secrets.dest_directory;
      app_configs_dir = config.settings.system.app_configs.dest_directory;
      deploy_dir = "/opt/${deploy_dir_name}";
      pre-compose_script_path = "${deploy_dir}/${pre-compose_script}";
    in {
      inherit enable;
      serviceConfig = {
        Type = "oneshot";
        WorkingDirectory = "-${deploy_dir}";
      };

      /*
        We need to explicitly set the docker runtime dependency
      since docker-compose does not depend on docker.
      Nix is included so that nix-shell can be used in the external scripts
      called dynamically by this function.
      Bash is included because several pre-compose scripts depend on it.
      */
      path = with pkgs; [nix docker bash];

      environment = let
        inherit (config.settings.system) github_private_key;
        inherit (config.settings.system.org) env_var_prefix;
      in {
        # We need to set the NIX_PATH env var so that we can resolve <nixpkgs>
        # references when using nix-shell.
        inherit (config.environment.sessionVariables) NIX_PATH;
        GIT_SSH_COMMAND = concatStringsSep " " [
          "${pkgs.openssh}/bin/ssh"
          "-F /etc/ssh/ssh_config"
          "-i ${github_private_key}"
          "-o IdentitiesOnly=yes"
          "-o StrictHostKeyChecking=yes"
        ];
        "${env_var_prefix}_SECRETS_DIRECTORY" = secrets_dir;
        "${env_var_prefix}_CONFIGS_DIRECTORY" = app_configs_dir;
        "${env_var_prefix}_DEPLOY_DIR" = deploy_dir;
      };
      script = let
        docker_creds_prefix = "docker_private_repo_creds";
        docker_creds_prefix_length = builtins.stringLength docker_creds_prefix;
        forEachDockerRepo = body: ''
          for secret_file in $(ls "${secrets_dir}"); do
            if [ "''${secret_file::${toString docker_creds_prefix_length}}" = \
                 "${docker_creds_prefix}" ]; then
              source "${secrets_dir}/''${secret_file}"
              ${body}
            fi
          done
        '';

        docker_login = forEachDockerRepo ''
          echo "logging in to ''${DOCKER_PRIVATE_REPO_URL}..."

          echo ''${DOCKER_PRIVATE_REPO_PASS} | \
          ${pkgs.docker}/bin/docker login \
            --username "''${DOCKER_PRIVATE_REPO_USER}" \
            --password-stdin \
            "''${DOCKER_PRIVATE_REPO_URL}"
        '';

        docker_logout = forEachDockerRepo ''
          ${pkgs.docker}/bin/docker logout "''${DOCKER_PRIVATE_REPO_URL}"
        '';
      in ''
        ${clone_and_reset_git {
          inherit config github_repo;
          clone_dir = deploy_dir;
          branch = git_branch;
        }}

        # Change to the deploy dir in case it did not exist yet
        # when the service started.
        # The previous command should have created it in that case.
        cd "${deploy_dir}"

        echo "Log in to all defined docker repos..."
        ${docker_login}


        if [ -x "${pre-compose_script_path}" ]; then
          echo "Running the pre-compose.sh script..."
          "${pre-compose_script_path}"
        else
          echo "Pre-compose script (${pre-compose_script_path}) does not exist or is not executable, skipping."
        fi

        ${extra_script}

        ${pkgs.docker-compose}/bin/docker-compose \
          --project-directory "${deploy_dir}" \
          ${concatMapStringsSep " " (s: ''--file "${deploy_dir}/${s}"'') docker_compose_files} \
          --ansi never \
          ${
          if restart
          then "restart"
          else ''up --detach --remove-orphans ${optionalString force_build "--build"}''
        }

        echo "Log out of all docker repos..."
        ${docker_logout}
      '';
    };
  in {
    config.lib.ext_lib = {
      inherit
        compose
        applyTwice
        filterEnabled
        concatMapAttrsToList
        nixosVersionOf
        find_duplicates
        find_duplicate_mappings
        recursiveMerge
        stringNotEmpty
        ifPathExists
        traceImportJSON
        keyIfExists
        host_name_type
        empty_str_type
        pub_key_type
        indentStr
        mkSudoStartServiceCmds
        reset_git
        clone_and_reset_git
        mkDeploymentService
        ;
    };
  }
