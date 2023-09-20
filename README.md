## Add a new host
### 0.a set the mac/ip match in the dhcp server
### 0.b set "ssh hostname" in nix (+ git add if new file)
ok
### 0.c. switch
ok

### 1. copy the public host key from the new machine into org-config/hosts/

ok

### 2. create a org-config/hosts/newhost.nix file

ok
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
