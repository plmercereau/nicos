# Nicos

_Nix Integrated Configuration and Operational Systems._

See the [documentation](https://nicos.mintlify.app) for more information, and [this configuration](https://github.com/plmercereau/nix-config) to see Nicos in action.

## Features

- VPN using Wireguard
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

## Contributing

### Documentation

Run the documentation website locally:

```sh
nix run .#doc
```

Regenerate the reference files:

```sh
nix run .#docgen
```
