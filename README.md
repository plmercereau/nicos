## Add a new host
### 0.a set the mac/ip match in the dhcp server
### 0.b set /etc/hosts or "ssh hostname" in nix (+ git add if new file)
### 0.c. switch

### 1. copy the public host key from the new machine into org-config/hosts/

ok

### 2. create a org-config/hosts/linux/newhost.nix file

Ideally, automate the process with `nixos-generate-config`, or dedicated pi4/zero2 scripts.
ssh newhost nixos-generate-config --show-hardware-config

### 3. rekey secrets

ok

### 4. commit push changes to git

```sh
git commit -m "added new machine"
git push
```

### 5. pull git in the new machine to /etc/nixos
```sh
```

### 6. switch to the new configuration

nixos-rebuild switch --flake .#hostname
