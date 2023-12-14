## Commands

<!-- TODO assuming github:plmercereau/cluster-flake -->

### Run the CLI

```sh
nix run github:plmercereay/cluster-flake
```

#### Create

```sh
nix run github:plmercereay/cluster-flake -- create
```

#### Deploy

```sh
nix run github:plmercereay/cluster-flake -- deploy machine1 [machine2 machine 3] [--all]
```

## Development

### Documentation

#### Update the options

```sh
nix run .#docgen
```

### Build

```sh
nix build .#documentation
```
