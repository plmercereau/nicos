# Nicos

_Nix Integrated Configuration and Operational Systems._

See [this configuration](https://github.com/plmercereau/nix-config) for illustration.

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
- Template for creating a new machine
- Machine installation using [nixos-anywhere](https://github.com/nix-community/nixos-anywhere)
- Build a SD image for Raspberry Pi
- Batch deployment using [deploy-rs](https://github.com/serokell/deploy-rs)

## Installation

### Prerequisites

#### Nix

Make sure you installed Nix before using Nicos. Please have a look at the [official installation instructions](https://nixos.org/download#download-nix).

<!-- TODO You also need to enable flake support  -->

#### Direnv and nix-direnv (recommended)

You can add the following lines in your home-manager configuration:

```nix
programs.direnv.enable = true;
programs.direnv.nix-direnv.enable = true;
```

### Install from scratch

<!--
You can use the CLI to create a new flake interactively:
```sh
nix run github:plmercereau/nicos -- init
``` -->

### Install on an existing flake

Here is a basic flake to use Nicos. See the configuration part of the documentation to know more about the arguments of the `nicos.lib.configure` wrapper.

```nix
{
  inputs = {
    nicos.url = "github:plmercereau/nicos";
  };

  outputs = {nicos, ...}:
    nicos.lib.configure {
      projectRoot = ./.;
      adminKeys = ["ssh-ed25519 XYZXYZXYZ"];
      nixos = {
        enable = true;
        path = "./hosts-nixos";
      };
    }
    {
      # Your additional flake outputs go here
    };
}
```

## Configuration

<!--
- give details about the configuration options by feature
 -->

## Creating a new machine

### Using the CLI

### Manually

## Installing a machine

### Using nixos-anywhere

### Raspberry Pi

## Deployment

## Commands

```sh
nix run github:plmercereau/nicos -- [OPTIONS] COMMAND [ARGS]...
```

Options:

```
  --ci / --no-ci  Run in CI mode, which disables prompts. Some
                  commands are not available in CI mode.
  --help          Show this message and exit.
```

Commands:

```
  build    Build a machine ISO image.
  create   Create a new machine in the cluster.
  deploy   Deploy one or several existing machines
  install  Deploy one or several existing machines
  secrets  Manage the secrets for the cluster
```

### Create a new machine

```sh
nix run github:plmercereau/nicos -- create
```

Options:

```
  --rekey / --no-rekey  Rekey the secrets after creating the machine
                        configuration.
  --help                Show this message and exit.
```

### Install a machine using nixos-anywhere

```sh
nix run github:plmercereau/nicos -- install [OPTIONS] [MACHINE] [IP]
```

Options:

```
  --user TEXT  User that will connect to the machine through nixos-anywhere.
  --help       Show this message and exit.
```

### Deploy

```sh
nix run github:plmercereau/nicos -- deploy [OPTIONS] [MACHINES]...
```

Options:

```
  --ip [vpn|lan|public]  Way to connect to the machines.
  --all                  Deploy all available machines.
  --nixos                Include the NixOS machines.
  --darwin               Include the Darwin machines.
  --help                 Show this message and exit.
```

### Build a SD image for a Raspberry Pi

```sh
nix run github:plmercereau/nicos -- build [OPTIONS] [MACHINE] [DEVICE]
```

Options:

```
  -k, --private-key-path TEXT  The path to the private key to use. Defaults to
                               ssh_<machine>_ed25519_key.
  --help                       Show this message and exit.
```

### Secrets

```sh
nix run github:plmercereau/nicos -- secrets [OPTIONS] COMMAND [ARGS]...
```

Commands:

```
  edit    Edit a secret
  export  Export the secrets config in the cluster as a JSON object
  list    List the secrets in the cluster
  rekey   Rekey all the secrets in the cluster.
  user    Edit a user password
  wifi    Edit wifi networks and passwords
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
