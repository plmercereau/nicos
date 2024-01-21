VERBOSE=1 nix repl --extra-experimental-features 'repl-flake' . --override-input nicos ../nicos

works:

```
nixosConfigurations.bastion.config.machines.fennec.networking.hostName
```

but if adding a module like this:

```nix
{config, ...}: {
    config
}
```
