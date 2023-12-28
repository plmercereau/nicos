## Features

- VPN
- Supports both Darwin and NixOS
- Distributed builds
- Secrets
  - user passwords
  - wifi
- Preconfigured hardware
  - Raspberry PI 4 and Zero 2 w
  - Intel NUC
  - Hetzner Cloud (ARM and x86)
  - Apple (M1 and x86)
- Impermanence
- CLI
  - Template for creating a new machine
  - Install a machine using [nixos-anywhere]()
  - Build a SD image for Raspberry Pi
  - Batch machines deployment using [deploy-rs]()

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
