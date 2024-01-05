{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    {%- if darwin %}
    nix-darwin.url = "github:lnl7/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    {%- endif %}
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nicos.url = "github:plmercereau/nicos";
    nicos.inputs = {
      nixpkgs.follows = "nixpkgs";
      {%- if darwin %}
      nix-darwin.follows = "nix-darwin";
      {%- endif %}
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
      {%- if nixos %}
      nixos = {
        enable = true;
        path = "{{ nixos_path }}";
      };
      {%- endif %}
      {%- if darwin %}
      darwin = {
        enable = true;
        path = "{{ darwin_path }}";
      };
      {%- endif %}
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
