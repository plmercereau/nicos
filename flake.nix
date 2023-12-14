{
  description = "Flake for managing my machines";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";

    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nix-darwin.url = "github:lnl7/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    cluster.url = "./cluster-flake";
    cluster.inputs = {
      nixpkgs.follows = "nixpkgs";
      nix-darwin.follows = "nix-darwin";
      home-manager.follows = "home-manager";
    };
  };

  outputs = {
    cluster,
    flake-utils,
    nixpkgs,
    ...
  }:
    cluster.lib.configure {
      projectRoot = ./.;
      clusterAdminKeys = [
        # badger
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCyxrQiE8bx1R9SG4fuNebXP8oq1duReM7E7W2M0i0fsC3PrKwQ6c9R4qzNQLREeWwtCWV0KEl0K+iriiIPa7D5psEASJapGyi5NtqEqZbM+a8BGQNdy82zEU4xU6IA4GyjxqPb/0zRiEh//4RuePZGNItW2Gl+1ZvOA1UTsHZKpGgZxWewoGdtm6EwscTy+5A4uanFWmxtpajy5J1GVR038quQLszSsTfTRr0gA80+uQbahHlGmP9HlyXrjaeKtSz9XTT95XmC/rVJkIKBYEIEf2fyV+O3hB1cxh+fb/lHFqoIJrES1qU4TAzs58Ioj0Jd3xlPGa96VJewrNXKbFjP"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGd6o/NuO04nLqahrci03Itd/1yoK76ZpzKGgpwAEctb"
        # puffin
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCzHVK8afzDVzWFRhditSwYRHbAXxFTSH2UDjCZUcKLwkTvUkSjV64FIjWQ8ftu5FreY5LFuwLiNfyFRlWAxYrTHs2pjrjr/iLNROc/PbFy8pA+KupFkB9DqG2MUyzUuUdcO57mW0bO3xXkoXzaqhQ0/rEnwp5z9QSOw8HG2/C8rDxQ8Er+gKK3nPgnzjXyut9JP28/+++dSPXFvWXdT4zF2lrF4iKhUIsYZtF8wjUPVWsKzt3FBkshFkTvlFGbtMzxAQIhHrpmQjopQXhue+ZQpZmXI0wOonzXW/AUzFvMyekrYy0CFqyWnL5xygxYXfvgByffHwAZuX/fDhQZrn7/56f9BNyylkr2GFKlMR8OqSh8HqxNQDz24yww93B6+ZceFIubfMYGNs3TcQREllJqhOMmd8OyjZljmL+zajXXKmHjeh2bibw+klB3RBBULy9TM0am1OD6xqM+N5o7Uj3kE7mnSbiajWGUssSlkSlvMl/kO32XK8VUDyvMML7V27zK4g2kScFPo4fQiazWj4X0OOBYhiWGXkjvm7ws52XNRkMp+NYHjx+F7XBzG7qiyfTDGPcA4aVbwGuIjV20081UmaNXw9JrrUdQ4hQrl0JK4COe6XV4wIarhPCtR+tMHDdf0hxY8ExXT/WerK+9amqOPGcXS60XdohvXyNmJ5OX1Q=="
      ];
      nixosHostsPath = "./hosts-nixos";
      darwinHostsPath = "./hosts-darwin";
      usersPath = "./users";
      wifiPath = "./wifi";
      extraModules = [./shared.nix];
    } (flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShells = {
        inherit (cluster.devShells.${system}) default;
      };

      packages = cluster.packages.${system};

      apps = {
        inherit (cluster.apps.${system}) default;

        # Browse the flake using nix repl
        repl = flake-utils.lib.mkApp {
          drv = pkgs.writeShellScriptBin "repl" ''
            confnix=$(mktemp)
            echo "builtins.getFlake (toString $(git rev-parse --show-toplevel))" >$confnix
            trap "rm $confnix" EXIT
            nix repl $confnix
          '';
        };
      };
    }));
}
