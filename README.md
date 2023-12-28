## Features

- VPN using Wireguard
- Supports both [Darwin](https://github.com/LnL7/nix-darwin) and [NixOS](https://nixos.org)
- Distributed Nix builds
- Secrets
  - user passwords
  - wifi
- Preconfigured hardware
  - Raspberry PI 4 and Zero 2 W
  - Intel NUC
  - Hetzner Cloud (ARM and x86)
  - Apple (M1 and x86)
- [Impermanence](https://github.com/nix-community/impermanence)
- CLI
  - Template for creating a new machine
  - Install a machine using [nixos-anywhere](https://github.com/nix-community/nixos-anywhere)
  - Build a SD image for Raspberry Pi
  - Batch machines deployment using [deploy-rs](https://github.com/serokell/deploy-rs)

## Commands

### Run the CLI

```sh
nix run github:plmercereau/nicos -- --help
```

#### Create a new machine

```sh
nix run github:plmercereau/nicos -- create
```

#### Install a machine using nixos-anywhere

#### Deploy

```sh
nix run github:plmercereau/nicos -- deploy --help
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
