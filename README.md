## Add a new host
### 0.a set the mac/ip match in the dhcp server
### 0.b set /etc/hosts or "ssh hostname" in nix (+ git add if new file)
### 0.c. switch

### 1. copy the public host key from the new machine into org-config/hosts/

```sh
TARGET_HOST=machine
scp nixos@$TARGET_HOST:/etc/ssh/ssh_host_ed25519_key.pub org-config/hosts/linux/$TARGET_HOST.key
git add org-config/hosts/linux/$TARGET_HOST.key
```
### 2. create a org-config/hosts/linux/newhost.nix file

Ideally, automate the process with `nixos-generate-config`, or dedicated pi4/zero2 scripts.
ssh newhost nixos-generate-config --show-hardware-config

### 3. rekey secrets

```sh
just secrets-update
```

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
