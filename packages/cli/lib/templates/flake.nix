{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nicos.url = "github:plmercereau/nicos";
    nicos.inputs = {
      nixpkgs.follows = "nixpkgs";
      home-manager.follows = "home-manager";
    };
  };

  outputs = {nicos, ...}:
    nicos.lib.configure {
      projectRoot = ./.;
      adminKeys = [
        # SSH keys of {{ user }}
        {%- for key in admin_keys %}
        "{{ key }}"
        {%- endfor %}
      ];
      extraModules = [
        ./shared.nix
      ];
      machinesPath = "{{ machines_path }}";
      {%- if users %}
      users = {
        enable = true;
        path = "{{ users_path }}";
      };
      {%- endif %}
      {%- if wifi %}
      wifi = {
        enable = true;
        path = "{{ wifi_path }}";
      };
      {%- endif %}
      {%- if builders %}
      builders = {
        enable = true;
        path = "{{ builders_path }}";
      };
      {%- endif %}
    }
    {
      # the rest of the flake goes there
    };
}
