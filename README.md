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

## Development

### Documentation

To update the options:

```sh
nix run .#docgen
```
